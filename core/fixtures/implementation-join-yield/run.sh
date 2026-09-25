#!/usr/bin/env bash
# implementation-join-yield — the Stop hook must let the lead YIELD while a
# backgrounded wait-beat is live (Rule 29, v0.81.0), and must STILL block a
# genuine stall.
#
# THE DEFECT THIS ADDRESSES. `ai-dlc-continue.sh` force-continues every text-only
# turn during an active pipeline (Rule 3). A lead waiting on teammates is
# therefore shoved through dozens of forced continuations per implementation
# phase (measured: 45-150/day on the reference consumer). Check 2b lets the lead
# END ITS TURN iff `scripts/ai-dlc/wait-for-deliverable.sh` has a backgrounded beat
# genuinely sleeping — signalled by an unexpired `.beat-inflight` marker, which is
# self-proving of re-invocation: that same background `Bash` exits and re-invokes
# the idle lead.
#
# THE TRAP THIS FIXTURE EXISTS TO AVOID. "Deliverable absent" was the tempting
# sensor and it is UNSAFE — it does not imply a live task will re-invoke the lead,
# so it would authorize a yield into a permanent SILENT stall, the exact class the
# always-block hook could never produce. The safe sensor is the marker, and every
# non-live marker state (missing, empty, garbage, expired, unreadable) MUST fall
# through to the block. An allow that fires when no beat is live reads exactly
# like a healthy yield — so EACH ALLOW ASSERTS the `ALLOWED_BY_LIVE_BEAT` flow-log
# line, never merely the absence of a block (which an empty output, or a crash,
# passes vacuously).
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking the hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# The harness's own block cap clamps the hook's EFF_MAX, so an operator who exports it
# would move every rapid-fire count asserted below. Section 8f sets it per command.
unset CLAUDE_CODE_STOP_HOOK_BLOCK_CAP
# Resolved BEFORE any arm puts a `date` shim first on PATH (section 8).
REAL_DATE="$(command -v date)"

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
STOP_HOOK="$(pick "$HERE/../../hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../.claude/hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../core/hooks/ai-dlc-continue.sh")"
[ -n "$STOP_HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-continue.sh" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

drive_stop() { # <work> -> stdout (block JSON, or empty on allow)
  printf '{"session_id":"t","transcript_path":""}' \
    | CLAUDE_PROJECT_DIR="$1" bash "$STOP_HOOK" 2>/dev/null
}
blocked()     { case "$1" in *'"decision":"block"'*|*'"decision": "block"'*) return 0 ;; esac; return 1; }
LOG='_bmad-output/pipeline-continuation-log.md'
fired_live()  { grep -q 'ALLOWED_BY_LIVE_BEAT' "$1/$LOG" 2>/dev/null; }
fired_pause() { grep -q 'ALLOWED_BY_PAUSE'     "$1/$LOG" 2>/dev/null; }

echo "implementation-join-yield:"

# =============================================================================
# 1. THE STALL still blocks. No live beat + active pipeline + text-only turn.
# =============================================================================
W="$(bash "$HERE/seed.sh" no-marker)"; OUT="$(drive_stop "$W")"
if blocked "$OUT"; then ok "no beat marker: a genuine stall is still BLOCKED (Rule 3 intact)"
else bad "no beat marker: the stall was ALLOWED — Rule 3 anti-stall is gone"; fi
rm -rf "$W"

# =============================================================================
# 2. THE YIELD is allowed — and decided in the PRESENCE of In-Flight rows the
#    hook must ignore (the dry-run: marker drives the decision, not the table).
# =============================================================================
W="$(bash "$HERE/seed.sh" live-marker)"; OUT="$(drive_stop "$W")"
if blocked "$OUT"; then bad "live beat: the yield was BLOCKED — the forced-continuation churn is back"
elif fired_live "$W"; then ok "live beat: the yield is ALLOWED via Check 2b (ALLOWED_BY_LIVE_BEAT logged)"
else bad "live beat: no block, but Check 2b did NOT fire — the allow came from elsewhere or a crash"; fi
if grep -q 'In-Flight Teammates' "$W/_bmad-output/pipeline-snapshot.md" 2>/dev/null; then
  ok "...decided WITH a populated In-Flight Teammates table present (the hook never parses it)"
else
  bad "fixture snapshot lacks the In-Flight section — the ignore-the-row-wording property is untested"
fi
rm -rf "$W"

# =============================================================================
# 3. FAIL-SAFE — every non-live marker state falls through to BLOCK.
# =============================================================================
# missing (case 1 above), expired, non-numeric, empty, unreadable. If ANY of
# these allowed, a dead beat would open a yield into a silent stall — strictly
# worse than the churn it replaces.
for c in expired-marker garbage-marker empty-marker marker-is-dir; do
  W="$(bash "$HERE/seed.sh" "$c")"; OUT="$(drive_stop "$W")"
  if blocked "$OUT" && ! fired_live "$W"; then ok "$c: falls through to BLOCK (fail-safe, no false allow)"
  else bad "$c: did NOT block — a non-live marker opened the yield into a silent stall"; fi
  rm -rf "$W"
done

# =============================================================================
# 4. PRECEDENCE — the operator pause (Check 1) still wins, even with a live beat.
# =============================================================================
W="$(bash "$HERE/seed.sh" paused)"; OUT="$(drive_stop "$W")"
if blocked "$OUT"; then bad "paused: BLOCKED — the operator-pause allow was cannibalized by Check 2b"
elif fired_pause "$W" && ! fired_live "$W"; then ok "paused: allowed by the PAUSE path, not Check 2b (decision order preserved)"
else bad "paused: allowed, but not via the pause path — Check 2b preempted Check 1"; fi
rm -rf "$W"

# =============================================================================
# 5. GATING — Check 2b sits behind Check 2. A live marker with NO snapshot must
#    not manufacture an allow of its own.
# =============================================================================
W="$(bash "$HERE/seed.sh" no-snapshot)"; OUT="$(drive_stop "$W")"
if blocked "$OUT"; then bad "no snapshot: BLOCKED — the no-pipeline allow (Check 2) is gone"
elif fired_live "$W"; then bad "no snapshot: Check 2b fired with no active pipeline — it must gate on Check 2 first"
else ok "no snapshot: allowed by Check 2 (no pipeline); Check 2b never consulted"; fi
rm -rf "$W"

# =============================================================================
# 6. PROGRESS IS MEASURED BY THE CLOCK, not asserted by the beat's existence.
# =============================================================================
# THE DEFECT THESE ARMS EXIST TO CATCH, and the reason section 6 used to assert
# its OPPOSITE. The live-beat path wiped the whole block-state file, so the next
# block read `LAST_TS=0`, computed a delta of one and a half billion seconds,
# took the "gap > window, progress happened" branch, and pinned the rapid-fire
# counter at 1 forever. `BACKOFF` was then unreachable by any sequence with a
# beat between two blocks -- which is the sequence a join-wait stall IS. The old
# arm here REQUIRED the wipe (`the counter SURVIVED a live-beat allow` was its
# FAIL text), so the fixture certified the defect.
#
# WHY A SEQUENCE AND NOT A PRE-SEEDED COUNTER. The old arm seeded a hot counter
# and drove ONE invocation, which can only observe what the hook writes, never
# what the next turn READS. The property is a state machine across turns, so the
# arms drive it as one.
#
# THE OFFENDER AND THE NEAR-MISS DIFFER IN ONE VARIABLE — whether the beat
# CONSUMED TIME — and in nothing else. Same event shape, same marker handling,
# same number of blocks. Without that pairing an arm that flags every sequence
# reads exactly like one that discriminates.
beat_on()  { printf '%s' "$(( $(date +%s) + 100 ))" > "$1/_bmad-output/.beat-inflight"; }
beat_off() { rm -f "$1/_bmad-output/.beat-inflight"; }
# Push the recorded block timestamp back, so the NEXT block reads a real elapsed
# gap. This is how a beat that genuinely slept is expressed without sleeping:
# the fixture cannot spend 30s per arm. It rewrites the hook's own OUTPUT, never
# its input grammar. These arms pass no transcript, so the two-line file it writes
# is exactly what the hook's time-test fallback reads. The gap is 4000s, past the
# 3600s window of section 9's widened-window mutant, so that mutant is owned by
# arm 8c alone and does not also turn this near-miss red.
age_state() {
  _sf="$1/_bmad-output/pipeline-block-state.txt"; [ -f "$_sf" ] || return 0
  _t="$(sed -n '1p' "$_sf")"; _c="$(sed -n '2p' "$_sf")"
  printf '%s\n%s\n' "$(( _t - 4000 ))" "$_c" > "$_sf"
}
# The mirror of `age_state`: rewrite the recorded block timestamp to NOW, so
# the next block reads a gap of zero. The rapid side of the clock has to be
# pinned too — arm 6a needs nine stop-hook calls inside RAPID_WINDOW_SECONDS
# (core/hooks/ai-dlc-continue.sh:93), and the pre-push pool spreads real calls
# past it, which resets the counter and reads as "no BACKOFF". Used ONLY by 6a:
# pinning before every block would undo `age_state` in 6b and turn the
# slow-beat near-miss red.
pin_state() {
  _sf="$1/_bmad-output/pipeline-block-state.txt"; [ -f "$_sf" ] || return 0
  _c="$(sed -n '2p' "$_sf")"
  printf '%s\n%s\n' "$(date +%s)" "$_c" > "$_sf"
}
# Drive one event sequence: B = block turn (no beat), L = live-beat turn,
# G = the previous beat consumed real time, R = the previous beat consumed
# none (pin the rapid side). Echoes the decision sequence.
drive_seq() {
  _w="$1"; shift
  for _e in "$@"; do
    case "$_e" in
      G) age_state "$_w"; continue ;;
      R) pin_state "$_w"; continue ;;
      L) beat_on "$_w" ;;
      B) beat_off "$_w" ;;
    esac
    drive_stop "$_w" >/dev/null
  done
  # ENTRIES ONLY, via the grammar the log's own header prescribes: one event is
  # one `## <timestamp> -- <EVENT>` line. A bare token grep also matches the
  # header, which names every event type in its legend — measured while writing
  # these arms, where it put three phantom `BACKOFF`s in front of every sequence
  # and made 6a pass without the detector firing at all.
  sed -n 's/^## [^ ]* -- //p' "$_w/$LOG" 2>/dev/null \
    | grep -E '^(BLOCKED \(rapid-fire [0-9]+/[0-9]+\)|BACKOFF|ALLOWED_BY_LIVE_BEAT)$' | tr '\n' ' '
}
backed_off() { case "$1" in *BACKOFF*) return 0 ;; esac; return 1; }

# 6a. THE OFFENDER — the reference consumer's measured sprint-305 shape: a block,
#     an instantly-returning beat, a block, a beat, ... Every beat consumes no
#     time, so nothing is progressing and the stall MUST be reported.
W="$(bash "$HERE/seed.sh" sequence)"; SEQ="$(drive_seq "$W" B L R B L R B L R B L R B)"
if backed_off "$SEQ"; then ok "beat-churn stall: BACKOFF is reached through interleaved live beats (the detector can fire)"
else bad "beat-churn stall: no BACKOFF in [$SEQ] — a beat between every pair of blocks still pins the counter, so no stall can ever be confirmed"; fi
case "$SEQ" in *'ALLOWED_BY_LIVE_BEAT'*) ok "...and the yields themselves were still ALLOWED (the backoff did not come from losing Check 2b)" ;;
  *) bad "beat-churn stall: no ALLOWED_BY_LIVE_BEAT in [$SEQ] — Check 2b stopped firing, so this arm proves nothing about the counter" ;; esac
rm -rf "$W"

# 6b. THE NEAR-MISS — the identical event shape, except each beat CONSUMED real
#     time. That is a healthy long join and it must stay silent.
W="$(bash "$HERE/seed.sh" sequence)"; SEQ="$(drive_seq "$W" B L G B L G B L G B L G B)"
if backed_off "$SEQ"; then bad "slow-beat near-miss: BACKOFF fired in [$SEQ] — a healthy long join is being reported as a stall"
elif case "$SEQ" in *'rapid-fire 1/3'*) false ;; *) true ;; esac; then
  bad "slow-beat near-miss: no 'rapid-fire 1/3' in [$SEQ] — the hook emitted nothing recognizable and the quiet reads vacuously"
else ok "slow-beat near-miss: stays quiet — a beat that consumed time resets the counter through the window test"; fi
rm -rf "$W"

# 6c. A YIELD BURST alone must never trip the backoff. Nothing on the live-beat
#     path touches the counter; only a BLOCK does. This is the property the
#     deleted wipe was reasoned to protect, held here without it.
W="$(bash "$HERE/seed.sh" sequence)"; SEQ="$(drive_seq "$W" B B B L L L L L L)"
if backed_off "$SEQ"; then bad "yield burst: BACKOFF fired in [$SEQ] — a run of legitimate yields tripped the stall detector"
elif case "$SEQ" in *'ALLOWED_BY_LIVE_BEAT'*) false ;; *) true ;; esac; then
  bad "yield burst: no ALLOWED_BY_LIVE_BEAT in [$SEQ] — the yields never happened, so the quiet proves nothing"
else ok "yield burst: six live-beat allows leave the rapid-fire counter untouched"; fi
rm -rf "$W"

# =============================================================================
# 7. THE FLOW LOG NEVER PRINTS AN EPOCH AS A DELTA.
# =============================================================================
# `Seconds since previous block` is read by a human deciding whether a gap was a
# pause or a stall. With no previous block recorded the raw subtraction yields
# the current epoch — a number that reads as an interval and is off by fifty
# years. All 15 of the reference consumer's sprint-305 blocks printed one.
W="$(bash "$HERE/seed.sh" sequence)"; drive_seq "$W" B B >/dev/null
DELTAS="$(sed -n 's/^- Seconds since previous block: //p' "$W/$LOG" 2>/dev/null)"
# HERE-STRINGS, NOT `printf | grep -q` — I54/I54b. This file sets `pipefail`, and
# a reader that leaves at its first match while the writer is still pushing makes
# the pipeline answer with the WRITER's EPIPE, so the test reports NOT-FOUND on
# input that contains the pattern. It is a size threshold, not a race. Both arms
# below decide a verdict on that status, which is exactly the shape the invariant
# is looking for; the first draft of this section shipped the pipeline form and
# the gate failed twelve fixtures on it.
if [ -z "$DELTAS" ]; then bad "delta print: no 'Seconds since previous block' line was emitted at all — this arm cannot see its subject"
elif grep -qE '^[0-9]{9,}$' <<< "$DELTAS"; then
  bad "delta print: an epoch-scale value reached the flow log ($(tr '\n' ' ' <<< "$DELTAS")) — a broken clock reading as a long quiet gap"
elif grep -q 'first block' <<< "$DELTAS"; then
  ok "delta print: the first block reports 'first block', never a raw epoch"
else bad "delta print: the first block printed '$(head -1 <<< "$DELTAS")' — expected the 'first block' wording"; fi
rm -rf "$W"

# =============================================================================
# 8. THE STALL RUN IS KEYED ON THE TOOL CALL, NOT ONLY THE CLOCK (transcript path).
# =============================================================================
# THE DEFECT. The run used to continue only when a block landed within 30s of the
# previous one, so a lead retrying a stop every 45s was blocked forever by the hook
# and released by the HARNESS's block cap instead -- which resets only on a tool call,
# never on elapsed time. A block now continues the run on NO NEW TOOL CALL or under
# 30s, and resets only on both. Every arm above passes `"transcript_path":""`, so
# none of them can see the tool test; these drive a real JSONL transcript.
#
# THE CLOCK IS A `date` SHIM, NOT age_state/pin_state. Those rewrite the state file
# as two lines and would drop the tool mark on line 3, turning every arm below into
# a test of the time fallback. The shim answers `date +%s` from a file the driver
# advances; every other `date` call goes to the real binary.
#
# EVERY ARM ASSERTS A DECISION SEQUENCE AS A VALUE -- the log's own entry grammar,
# joined -- never "no BACKOFF", which an empty log passes.
SCHEMA="$(pick "$HERE/../../schemas/pause-routing.json" \
               "$HERE/../../../core/schemas/pause-routing.json" \
               "$HERE/../../../.claude/schemas/pause-routing.json")"
[ -n "$SCHEMA" ] || { echo "FIXTURE ERROR: cannot locate pause-routing.json (arm 8g's guard reads its vocabulary there)" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq required" >&2; exit 2; }
T0=1790000000

tx_world() { # tx_world <seed-case> -> world dir with a date shim at $T0
  _tw="$(bash "$HERE/seed.sh" "$1")" || return 1
  mkdir -p "$_tw/.bin"
  printf '#!/bin/sh\nif [ "${1:-}" = "+%%s" ]; then cat "%s/.now"; else exec "%s" "$@"; fi\n' "$_tw" "$REAL_DATE" > "$_tw/.bin/date"
  chmod +x "$_tw/.bin/date"; echo "$T0" > "$_tw/.now"; echo jy > "$_tw/.sid"
  printf '%s' "$_tw"
}
# tx_seq <world> <hook> <cap|-> <event...> -> one letter per Stop: b block, H handoff-guard
# block, a allow.  T  a text-only turn: a typed Stop-hook feedback record, then an
#                     assistant text record with NO top-level `type`
#                  P  T, except the prose merely MENTIONS tool_use (a raw grep moves on
#                     it; the hook must not). Only arm 8a uses it, so the raw-grep mutant
#                     is owned by 8a and does not also turn every other text-only arm red
#                  U  a turn with a NEW tool call: an assistant tool_use record with NO
#                     top-level `type`, its result, and typed assistant text
#                  L  arm a wait-beat (a typed tool_use record) and Stop while it is live
#                  S  Stop with no beat live
#                  +N advance the shimmed clock N seconds
#                  @X the next Stops carry session_id X
tx_seq() {
  _w="$1"; _h="$2"; _cap="$3"; shift 3; _s=""; _k=0
  for _e in "$@"; do
    case "$_e" in
      +*) echo $(( $(cat "$_w/.now") + ${_e#+} )) > "$_w/.now"; continue ;;
      @*) echo "${_e#@}" > "$_w/.sid"; continue ;;
      T)  printf '%s\n' '{"type":"user","message":{"role":"user","content":"Stop hook feedback: Pipeline is active."}}' \
            '{"message":{"role":"assistant","content":[{"type":"text","text":"Still here, waiting on the gate."}]}}' \
            >> "$_w/transcript.jsonl"; continue ;;
      P)  printf '%s\n' '{"type":"user","message":{"role":"user","content":"Stop hook feedback: Pipeline is active."}}' \
            '{"message":{"role":"assistant","content":[{"type":"text","text":"Still here. My next turn will emit a tool_use for the gate."}]}}' \
            >> "$_w/transcript.jsonl"; continue ;;
      U)  _k=$((_k+1))
          printf '%s\n' "{\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"toolu_jyu$_k\",\"name\":\"Skill\",\"input\":{}}]}}" \
            "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"toolu_jyu$_k\"}]}}" \
            '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Skill done."}]}}' \
            >> "$_w/transcript.jsonl"; continue ;;
      L)  _k=$((_k+1))
          printf '%s\n' "{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"toolu_jyb$_k\",\"name\":\"Bash\",\"input\":{\"command\":\"scripts/ai-dlc/wait-for-deliverable.sh x\",\"run_in_background\":true}}]}}" \
            >> "$_w/transcript.jsonl"
          echo $(( $(cat "$_w/.now") + 100 )) > "$_w/_bmad-output/.beat-inflight" ;;
      S)  rm -f "$_w/_bmad-output/.beat-inflight" ;;
    esac
    _in="$(printf '{"session_id":"%s","transcript_path":"%s"}' "$(cat "$_w/.sid")" "$_w/transcript.jsonl")"
    if [ "$_cap" = - ]; then
      _r="$(PATH="$_w/.bin:$PATH" CLAUDE_PROJECT_DIR="$_w" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$_h" <<< "$_in" 2>/dev/null)"
    else
      _r="$(CLAUDE_CODE_STOP_HOOK_BLOCK_CAP="$_cap" PATH="$_w/.bin:$PATH" CLAUDE_PROJECT_DIR="$_w" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$_h" <<< "$_in" 2>/dev/null)"
    fi
    case "$_r" in *'HANDOFF GUARD'*) _s="${_s}H" ;; *'"decision":"block"'*|*'"decision": "block"'*) _s="${_s}b" ;; *) _s="${_s}a" ;; esac
  done
  printf '%s' "$_s"
}
tx_events() { # the log's entries, one per line, by the header's own `## <ts> -- <EVENT>` grammar
  sed -n 's/^## [^ ]* -- //p' "$1/$LOG" 2>/dev/null \
    | grep -E '^(BLOCKED \(rapid-fire [0-9]+/[0-9]+\)|BACKOFF|ALLOWED_BY_LIVE_BEAT|HANDOFF_GUARD_BLOCK \([0-9]+/[0-9]+\))$' | tr '\n' ' '
}
tx_rows() { sed -n 's/^- Tool call since previous block: //p' "$1/$LOG" 2>/dev/null | tr '\n' ' '; }
# A THREE-LINE STATE FILE in the shape stall_run_write emits (epoch, count, mark), for the
# single-transition arms. Seeding it rather than producing it keeps those arms reading ONE
# transition, so they do not also depend on the hook persisting its own mark (arm 8a owns that).
tx_state() { printf '%s\n%s\n%s\n' "$2" "$3" "$4" > "$1/_bmad-output/pipeline-block-state.txt"; }

# Each arm: arm_8x <hook> -> 0 pass, 1 fail; ARM_MSG carries the evidence. Written as
# functions so section 9 drives the SAME arms against each mutant.
arm_8a() { # text-only at 45s and at 300s: blocks, then BACKOFF by the 4th Stop
  ARM_MSG=""; _rc=0
  for _sp in 45 300; do
    _w="$(tx_world transcript)"
    _d="$(tx_seq "$_w" "$1" - S +$_sp P S +$_sp P S +$_sp P S +$_sp P S)"
    _why="$(sed -n '/-- BACKOFF$/{n;n;p;}' "$_w/$LOG" 2>/dev/null)"
    ARM_MSG="$ARM_MSG [${_sp}s: $_d | $(tx_rows "$_w")| $_why]"
    [ "$_d" = bbbab ] || _rc=1
    case "$_why" in *'no tool call across 4 consecutive blocks'*) ;; *) _rc=1 ;; esac
    # The 5th Stop reads `unknown`: BACKOFF removed the state file, so a fresh run starts.
    [ "$(tx_rows "$_w")" = 'unknown no no unknown ' ] || _rc=1
    rm -rf "$_w"
  done
  return $_rc
}
arm_8b() { # a new tool call before every Stop, 5s apart, live beats between: BACKOFF (beat churn)
  _w="$(tx_world transcript)"
  _d="$(tx_seq "$_w" "$1" - U S +5 L +5 U S +5 L +5 U S +5 L +5 U S)"
  _ev="$(tx_events "$_w")"; _why="$(sed -n '/-- BACKOFF$/{n;n;p;}' "$_w/$LOG" 2>/dev/null)"
  ARM_MSG="[$_d | $_ev| $_why]"; rm -rf "$_w"
  [ "$_d" = bababaa ] || return 1
  [ "$_ev" = 'BLOCKED (rapid-fire 1/3) ALLOWED_BY_LIVE_BEAT BLOCKED (rapid-fire 2/3) ALLOWED_BY_LIVE_BEAT BLOCKED (rapid-fire 3/3) ALLOWED_BY_LIVE_BEAT BACKOFF ' ] || return 1
  # The detail must name the TIME test, which is what closed this run -- matched without the
  # window's value, so arm 8c alone owns the window's width.
  case "$_why" in *'consecutive rapid-fire blocks (within '*) return 0 ;; esac; return 1
}
arm_8c() { # a new tool call before every Stop, 45s apart: 9 blocks, never BACKOFF, every row `yes`
  _w="$(tx_world transcript)"
  tx_state "$_w" $((T0 - 45)) 1 "jy:toolu_seed"
  _d="$(tx_seq "$_w" "$1" - U S +45 U S +45 U S +45 U S +45 U S +45 U S +45 U S +45 U S +45 U S)"
  _ev="$(tx_events "$_w")"; _rows="$(tx_rows "$_w")"
  ARM_MSG="[$_d | $_rows]"; rm -rf "$_w"
  [ "$_d" = bbbbbbbbb ] || return 1
  # The FIRST row answers against the seeded three-line state, so it must read `yes`. The
  # later rows answer against state the hook wrote itself, and they read `yes` only if the
  # hook persisted its mark; arm 8a OWNS persistence, so here they are held to "never `no`"
  # -- a tool call before every Stop must never be read as none -- and not to `yes`.
  case "$_rows" in 'yes '*) ;; *) return 1 ;; esac
  case "$_rows" in *'no '*) return 1 ;; esac
  [ "$(grep -o 'rapid-fire 1/3' <<< "$_ev" | grep -c .)" = 9 ] || return 1
}
arm_8d() { # an OLD hook's two-line state file: the tool test is unanswered and time decides
  _w="$(tx_world transcript)"
  printf '%s\n%s\n' $((T0 - 4000)) 2 > "$_w/_bmad-output/pipeline-block-state.txt"
  _d="$(tx_seq "$_w" "$1" - T S)"; _ev="$(tx_events "$_w")"; _rows="$(tx_rows "$_w")"
  # CONTROL, same transcript, a THREE-line file carrying the unchanged mark: the tool test
  # answers `no` and the run continues -- so the reset above is the missing line, not the gap.
  _w2="$(tx_world transcript)"; tx_state "$_w2" $((T0 - 4000)) 2 "jy:toolu_seed"
  _d2="$(tx_seq "$_w2" "$1" - T S)"; _ev2="$(tx_events "$_w2")"; _rows2="$(tx_rows "$_w2")"
  ARM_MSG="[2-line: $_d $_ev| $_rows] [3-line: $_d2 $_ev2| $_rows2]"; rm -rf "$_w" "$_w2"
  [ "$_d$_ev$_rows" = 'bBLOCKED (rapid-fire 1/3) unknown ' ] || return 1
  [ "$_d2$_ev2$_rows2" = 'bBLOCKED (rapid-fire 3/3) no ' ] || return 1
}
arm_8e() { # a changed session_id over the SAME transcript is a tool call by construction
  _w="$(tx_world transcript)"; tx_state "$_w" $((T0 - 4000)) 1 "jy:toolu_seed"
  _rows="$(tx_seq "$_w" "$1" - @jy2 T S >/dev/null; tx_rows "$_w")"
  # CONTROL, identical but the SAME session: the mark is unchanged and the row reads `no`.
  _w2="$(tx_world transcript)"; tx_state "$_w2" $((T0 - 4000)) 1 "jy:toolu_seed"
  _rows2="$(tx_seq "$_w2" "$1" - T S >/dev/null; tx_rows "$_w2")"
  ARM_MSG="[new session: $_rows] [same session: $_rows2]"; rm -rf "$_w" "$_w2"
  [ "$_rows" = 'yes ' ] && [ "$_rows2" = 'no ' ]
}
arm_8f() { # CLAUDE_CODE_STOP_HOOK_BLOCK_CAP clamps EFF_MAX: 1 -> ba, 0 -> bbba (disabled), 2 -> bba
  ARM_MSG=""; _rc=0
  for _cp in 1:ba 0:bbba 2:bba; do
    _w="$(tx_world transcript)"
    _d="$(tx_seq "$_w" "$1" "${_cp%%:*}" S +5 T S +5 T S +5 T S)"
    ARM_MSG="$ARM_MSG [CAP=${_cp%%:*}: $_d]"; rm -rf "$_w"
    case "$_d" in "${_cp#*:}"*) ;; *) _rc=1 ;; esac
  done
  return $_rc
}
arm_8g() { # a slow text-only run of Check 0's handoff guard releases after EFF_MAX, row by row
  _w="$(tx_world handoff)"
  _d="$(tx_seq "$_w" "$1" - S +45 T S +45 T S +45 T S)"
  _ev="$(tx_events "$_w")"; _rows="$(tx_rows "$_w")"
  ARM_MSG="[$_d | $_ev| $_rows]"; rm -rf "$_w"
  [ "$_d" = HHHa ] || return 1
  [ "$_ev" = 'HANDOFF_GUARD_BLOCK (1/3) HANDOFF_GUARD_BLOCK (2/3) HANDOFF_GUARD_BLOCK (3/3) ' ] || return 1
  [ "$_rows" = 'unknown no no ' ]
}
ARMS_8="8a 8b 8c 8d 8e 8f 8g"
arm_desc() {
  case "$1" in
    8a) echo "text-only stall at 45s and 300s: blocks then BACKOFF on the 4th Stop, detail names the no-tool-call signal" ;;
    8b) echo "beat churn on the transcript path: a new tool call before every Stop 5s apart still reaches BACKOFF, closed by the 30s arm" ;;
    8c) echo "multi-skill progress: a new tool call before every Stop 45s apart blocks 9 times at 1/3, rows 'yes' and never 'no'" ;;
    8d) echo "a two-line (old hook) state file falls back to the time test: resets to 1, row 'unknown'; a three-line one continues" ;;
    8e) echo "a changed session_id over the same transcript reads as a tool call ('yes'); the same session reads 'no'" ;;
    8f) echo "CLAUDE_CODE_STOP_HOOK_BLOCK_CAP clamps EFF_MAX: 1 -> ba, 0 -> bbba, 2 -> bba" ;;
    8g) echo "a slow text-only handoff-guard run releases after EFF_MAX, each row carrying the tool-call line" ;;
  esac
}
for _a in $ARMS_8; do
  if "arm_$_a" "$STOP_HOOK"; then ok "$_a $(arm_desc "$_a")"
  else bad "$_a $(arm_desc "$_a") -- got $ARM_MSG"; fi
done

# =============================================================================
# 9. MUTANTS: each wrong implementation of the rule fails ITS OWN arm.
# =============================================================================
# Arms 8b-8e and 8g carry the ALLOW-shaped half of the rule -- "never BACKOFF",
# "resets to 1" -- which a hook that emits nothing does not pass only because each
# asserts a decision sequence by value. The mutants are what prove each arm is
# watching the property it names rather than any property.
#
# EACH MUTANT IS A COPY OF THE WHOLE HOOKS DIRECTORY: the hook sources
# ai-dlc-handoff-pending.sh from beside itself, and a lone copy silently skips it.
# Each edit is guarded by `cmp -s` (a sed that matched nothing is FIXTURE STALE, never
# a kill) and `bash -n`. The unmutated copy is driven through every arm of section 8
# first and must pass them all -- that is the control that the copy runs at all.
HOOK_DIR="$(cd "$(dirname "$STOP_HOOK")" && pwd)"
MUT_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/join-yield-mut-XXXXXX")"
mk_copy() { # mk_copy <name> -> path of ai-dlc-continue.sh inside a fresh copy of the hooks dir
  mkdir -p "$MUT_ROOT/$1" && cp -R "$HOOK_DIR/." "$MUT_ROOT/$1/" \
    && [ -f "$MUT_ROOT/$1/ai-dlc-handoff-pending.sh" ] && printf '%s' "$MUT_ROOT/$1/ai-dlc-continue.sh"
}
CTRL="$(mk_copy control)"
if [ -z "$CTRL" ]; then
  bad "FIXTURE BROKEN: the hooks directory copy is missing its sibling ai-dlc-handoff-pending.sh -- no mutant verdict below would be about a hook that ran"
else
  _cf=""
  for _a in $ARMS_8; do "arm_$_a" "$CTRL" || _cf="$_cf $_a"; done
  if [ -z "$_cf" ]; then ok "mutant control: the UNMUTATED copy of the hooks dir passes every arm of section 8"
  else bad "MUTANT HARNESS BROKEN: the unmutated copy fails$_cf -- a copy that cannot pass cannot score a kill"; fi
fi

# mut <name> <owning-arm> <sed-program> <what it implements>
# Scores the owning arm, and ONE arm the mutation must not touch (8f for every mutant but
# the clamp's own, which uses 8a) as a same-copy, presence-shaped control. Set
# JY_KILL_MATRIX=1 to score every section-8 arm against every mutant instead.
mut() {
  _m="$(mk_copy "$1")" || { bad "MUTANT $1: could not copy the hooks dir"; return; }
  if ! sed "$3" "$CTRL" > "$_m"; then bad "MUTANT $1: sed DIED -- the mutation never existed"; return; fi
  if cmp -s "$CTRL" "$_m"; then bad "FIXTURE STALE: mutation $1 matched nothing in $STOP_HOOK -- re-anchor it on the real line"; return; fi
  if ! bash -n "$_m" 2>/dev/null; then bad "FIXTURE STALE: mutant $1 does not parse -- a kill would be a syntax error"; return; fi
  if [ "${JY_KILL_MATRIX:-0}" = 1 ]; then
    _row=""; for _a in $ARMS_8; do if "arm_$_a" "$_m"; then _row="$_row $_a:pass"; else _row="$_row $_a:KILL"; fi; done
    printf '  matrix %-16s owner %s |%s\n' "$1" "$2" "$_row"
  fi
  if "arm_$2" "$_m"; then bad "MUTANT SURVIVED ($1: $4) -- arm $2 still passes, so it is not watching that property: $ARM_MSG"
  else ok "mutant ($1: $4) fails arm $2"; fi
  _ctl=8f; [ "$2" = 8f ] && _ctl=8a
  if "arm_$_ctl" "$_m"; then ok "...and the same copy still passes arm $_ctl (it runs; the kill is the mutation's)"
  else bad "MUTANT HARNESS BROKEN ($1): the copy also fails arm $_ctl -- $ARM_MSG"; fi
}
[ -n "$CTRL" ] && {
  # (i) Draft 1: the tool rule alone where the transcript answers, time only as the fallback.
  mut tool-only 8b 's/^  elif \[ "\$RUN_DELTA" -lt "\$RAPID_WINDOW_SECONDS" \]; then$/  elif [ "$RUN_TOOL" = unknown ] \&\& [ "$RUN_DELTA" -lt "$RAPID_WINDOW_SECONDS" ]; then/' \
      "the OR-delta dropped, a tool call alone resets"
  # (ii) The window widened until every retry counts as rapid.
  mut window-3600 8c 's/^RAPID_WINDOW_SECONDS=30$/RAPID_WINDOW_SECONDS=3600/' "the rapid window widened to 3600s"
  # (iii) A tool call never resets the run: release after N no matter what.
  mut no-reset-on-tool 8c 's/^    RUN_CNT=1; RUN_SIGNAL=reset$/    if [ "$RUN_TOOL" = yes ]; then RUN_CNT=$((RUN_CNT + 1)); else RUN_CNT=1; fi; RUN_SIGNAL=reset/' \
      "release after EFF_MAX regardless of tool calls"
  # (iv) The off-by-one clamp.
  mut clamp-cap-minus-1 8f 's/then EFF_MAX="\$_stop_cap"; fi$/then EFF_MAX=$((_stop_cap - 1)); fi/' "EFF_MAX clamped to CAP-1"
  # (v) Check 3 writes its state as the old two lines, so the mark never reaches line 3.
  mut mark-not-persisted 8a 's/^stall_run_write "\$STATE_FILE"$/printf '"'"'%s\\n%s\\n'"'"' "$NOW" "$RUN_CNT" > "$STATE_FILE"/' \
      "Check 3's tool mark not persisted to line 3"
  # (vi) Check 0 keeps the inline time-only test it had before the shared helper.
  mut check0-time-only 8g 's/^      stall_run "\$HANDOFF_STATE"; H_CNT="\$RUN_CNT"$/      stall_run "$HANDOFF_STATE"; H_CNT="$RUN_CNT"; if [ "$RUN_DELTA" -lt "$RAPID_WINDOW_SECONDS" ]; then H_CNT=$RUN_CNT; else H_CNT=1; RUN_CNT=1; fi/' \
      "Check 0 left on the time-only test"
  # (vii) A raw count as the mark: prose that merely says tool_use moves it.
  mut raw-grep-mark 8a 's/^  _tm_id="\$(tail -n 400 .*$/  _tm_id="$(grep -c tool_use "$TRANSCRIPT")"/' "a raw grep -c tool_use as the mark"
  # (viii) A mark that ignores the session: a new session over the same transcript reads `no`.
  # Pinned to this fixture's default id rather than dropped, so the marks the other arms
  # SEED stay byte-equal and the mutant moves only the one property arm 8e owns.
  mut mark-sans-session 8e 's/^  TOOL_MARK="\${SESSION_ID}:\${_tm_id:-none}"$/  TOOL_MARK="jy:${_tm_id:-none}"/' "the session id ignored by the mark"
}
rm -rf "$MUT_ROOT"

echo
if [ "$fails" -eq 0 ]; then echo "implementation-join-yield: PASS"; exit 0; fi
echo "implementation-join-yield: $fails assertion(s) FAILED" >&2
exit 1
