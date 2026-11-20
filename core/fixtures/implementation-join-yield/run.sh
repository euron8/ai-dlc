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

# EVERY TEMP DIR THIS RUN MAKES LIVES UNDER ONE RUN DIR, AND A KILL REAPS BOTH IT AND THE POOL.
# Sections 8-9 run ~two dozen background jobs, each forking hooks, jq and seeds; killed
# mid-run without this, they were measured orphaned and still writing `join-yield-*` dirs.
# TMPDIR is exported so seed.sh and every mktemp below land inside JY_RUN, which the trap
# removes -- and only a path this run named `join-yield-run-*` is ever removed.
JY_RUN="$(mktemp -d "${TMPDIR:-/tmp}/join-yield-run-XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
export TMPDIR="$JY_RUN"
# FREEZE TOP-DOWN, THEN TERMINATE. A tree snapshot taken while the pool is live is stale by the
# time it is killed: a job forks a fresh seed.sh between the `pgrep` and the `kill`, and that
# seed then writes a world AFTER the rm below -- measured, one `join-yield-*` dir left on INT.
# STOPping each parent before listing its children means nothing in the tree can fork again.
jy_freeze_tree() { kill -STOP "$1" 2>/dev/null; for _c in $(pgrep -P "$1" 2>/dev/null); do jy_freeze_tree "$_c"; done; }
jy_term_tree()   { for _c in $(pgrep -P "$1" 2>/dev/null); do jy_term_tree "$_c"; done; kill -TERM "$1" 2>/dev/null; kill -CONT "$1" 2>/dev/null; }
jy_cleanup() {
  _jp="$(jobs -p)"
  for _p in $_jp; do jy_freeze_tree "$_p"; done
  for _p in $_jp; do jy_term_tree "$_p"; done
  wait 2>/dev/null
  case "$JY_RUN" in */join-yield-run-*) rm -rf "$JY_RUN" ;; esac
}
trap 'jy_cleanup' EXIT
trap 'jy_cleanup; trap - EXIT; exit 130' INT
trap 'jy_cleanup; trap - EXIT; exit 143' TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
STOP_HOOK="$(pick "$HERE/../../hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../.claude/hooks/ai-dlc-continue.sh" \
                  "$HERE/../../../core/hooks/ai-dlc-continue.sh")"
[ -n "$STOP_HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-continue.sh" >&2; exit 2; }
_HD="$(cd "$(dirname "$STOP_HOOK")" && pwd)"; echo "HERMETIC-CONSUMED $_HD/ai-dlc-continue.sh"
[ -f "$_HD/ai-dlc-handoff-pending.sh" ] && echo "HERMETIC-CONSUMED $_HD/ai-dlc-handoff-pending.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: cannot source lib/layout.sh" >&2; exit 2; }

# PRE-WRAP GATE. A hook without the wrap would RUN when sourced (reading this shell's stdin and exiting), a silent
# green, so both halves are required before the load. Neither half predates the wrap: SKIP on a consumer, FIXTURE
# BROKEN in the distribution. Exactly one half is a respelled hook this fixture cannot drive, which FAILS.
[ -r "$STOP_HOOK" ] || { echo "FIXTURE ERROR: cannot read $STOP_HOOK -- an unreadable hook is not one that predates the wrap" >&2; exit 2; }
_pw_d=0; _pw_g=0
grep -qxF 'hkcont_main() {' "$STOP_HOOK" && _pw_d=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$STOP_HOOK" && _pw_g=1
case "$_pw_d$_pw_g" in
  11) : ;;
  00) echo "SKIP: implementation-join-yield: $STOP_HOOK predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) echo "  FAIL  $STOP_HOOK carries one half of the in-process wrap (hkcont_main line, column-0 source guard: $_pw_d$_pw_g) -- a respelled hook this fixture cannot drive" >&2; echo "implementation-join-yield: 1 assertion(s) FAILED" >&2; exit 1 ;;
esac
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$STOP_HOOK" || { echo "FIXTURE BROKEN: sourcing $STOP_HOOK defined nothing" >&2; exit 2; }
declare -F hkcont_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $STOP_HOOK defined no hkcont_main" >&2; exit 2; }

drive_stop() { # <work> [hook] -> stdout (block JSON, or empty on allow)
  printf '{"session_id":"t","transcript_path":""}' \
    | CLAUDE_PROJECT_DIR="$1" inproc_run "${STOP_HOOK%/*}/ai-dlc-continue.sh" hkcont_main 2>/dev/null
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
# 2p. THE PRODUCER'S FORM. wait-for-deliverable.sh writes `<epoch> <pid>`; the bare-epoch arm above
#     is the backward-compatibility proof, this one is the marker the shipping beat writes. Scored
#     by the same predicate (yield_live).
yield_live() { # yield_live <seed-case> [hook] -> 0 when the Stop is ALLOWED by Check 2b
  _yw="$(bash "$HERE/seed.sh" "$1")"; _yo="$(drive_stop "$_yw" "${2:-}")"
  if blocked "$_yo"; then YL_MSG=blocked; elif fired_live "$_yw"; then YL_MSG=live; else YL_MSG=allow-not-live; fi
  rm -rf "$_yw"; [ "$YL_MSG" = live ]
}
if yield_live live-marker-pid; then ok "live beat, producer form '<epoch> <pid>': the yield is ALLOWED via Check 2b (ALLOWED_BY_LIVE_BEAT logged)"
else bad "live beat, producer form '<epoch> <pid>': $YL_MSG — the hook does not read the marker wait-for-deliverable.sh writes"; fi

# =============================================================================
# 3. FAIL-SAFE — every non-live marker state falls through to BLOCK.
# =============================================================================
# missing (case 1 above), expired, non-numeric, empty, unreadable. If ANY of
# these allowed, a dead beat would open a yield into a silent stall — strictly
# worse than the churn it replaces.
for c in expired-marker expired-marker-pid garbage-marker empty-marker marker-is-dir; do
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
beat_on()  { printf '%s' 9999999999 > "$1/_bmad-output/.beat-inflight"; }
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
  printf '%s\n%s\n' 9999999999 "$_c" > "$_sf"
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
  printf '#!/bin/bash\nif [ "${1:-}" = "+%%s" ]; then cat "%s/.now"; else exec "%s" "$@"; fi\n' "$_tw" "$REAL_DATE" > "$_tw/.bin/date"
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
#                  Q  an assistant text record alone, with no user record before it (arm 8h)
#                  L  arm a wait-beat (a typed tool_use record) and Stop while it is live
#                  S  Stop with no beat live
#                  X  Stop with the lease left as it is, so the shimmed clock decides (arm 8i)
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
      Q)  printf '%s\n' '{"message":{"role":"assistant","content":[{"type":"text","text":"Still here."}]}}' \
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
      X)  : ;;
    esac
    _in="$(printf '{"session_id":"%s","transcript_path":"%s"}' "$(cat "$_w/.sid")" "$_w/transcript.jsonl")"
    if [ "$_cap" = - ]; then
      _r="$(PATH="$_w/.bin:$PATH" CLAUDE_PROJECT_DIR="$_w" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" inproc_run "$_h" hkcont_main <<< "$_in" 2>/dev/null)"
    else
      _r="$(CLAUDE_CODE_STOP_HOOK_BLOCK_CAP="$_cap" PATH="$_w/.bin:$PATH" CLAUDE_PROJECT_DIR="$_w" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" inproc_run "$_h" hkcont_main <<< "$_in" 2>/dev/null)"
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
# functions so each runs as one concurrent job.
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
  # The release is logged as Check 0's own BACKOFF; with the pause flag UP the pre-fix fall-through
  # was released by Check 1 instead and logged none. Either is a release here -- which site
  # releases is arm 8h's, in the world where the difference changes the decision.
  case "$_ev" in
    'HANDOFF_GUARD_BLOCK (1/3) HANDOFF_GUARD_BLOCK (2/3) HANDOFF_GUARD_BLOCK (3/3) '|\
    'HANDOFF_GUARD_BLOCK (1/3) HANDOFF_GUARD_BLOCK (2/3) HANDOFF_GUARD_BLOCK (3/3) BACKOFF ') ;;
    *) return 1 ;;
  esac
  [ "$_rows" = 'unknown no no ' ]
}
arm_8h() { # the 8g world with the pause flag DOWN: Check 0's backoff must release, not fall through
  _w="$(tx_world handoff)"; rm -f "$_w/_bmad-output/pipeline-paused.flag"
  # Q, not T: a Stop-hook feedback record is a newer USER turn, which ends the handoff request
  # the guard reads, so a T-driven run leaves Check 0 after one Stop and never reaches its backoff.
  _d="$(tx_seq "$_w" "$1" - S +45 Q S +45 Q S +45 Q S +45 Q S +45 Q S +45 Q S +45 Q S +45 Q S)"
  _why="$(sed -n 's/^- Handoff guard: //p' "$_w/$LOG" 2>/dev/null | head -n 1)"
  _bo="$(grep -c -- '-- BACKOFF$' "$_w/$LOG" 2>/dev/null)" || _bo=0
  ARM_MSG="[$_d | BACKOFF rows $_bo | $_why]"; rm -rf "$_w"
  # PRESENCE of the release, by the 4th Stop: an `a` in the first four letters.
  case "${_d%?????}" in *a*) ;; *) return 1 ;; esac
  # NO RUN OF MORE THAN EFF_MAX (3) CONSECUTIVE BLOCKS ANYWHERE in the nine: the fall-through
  # read `HHHbHHHbH`, a guard block handing straight on to Check 3's, past the harness's ninth.
  case "$_d" in *[Hb][Hb][Hb][Hb]*) return 1 ;; esac
  [ "${#_d}" = 9 ] || return 1
  [ "$_bo" -ge 1 ] || return 1
  case "$_why" in 'no tool call across '*) return 0 ;; esac; return 1
}
arm_8i() { # handoff.md step 1's beat: three deferred Stops within 30s, then the lease expires -> H
  _w="$(tx_world handoff)"
  # L re-stamps the lease to now+100 each time, as wait-for-deliverable.sh re-stamps every poll;
  # +200 carries the clock past the last stamp, and X stops on the expired lease untouched.
  _d="$(tx_seq "$_w" "$1" - L +5 L +5 L +200 X)"
  _df="$(grep -c -- '-- HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT$' "$_w/$LOG" 2>/dev/null)" || _df=0
  _ev="$(tx_events "$_w")"
  ARM_MSG="[$_d | deferred $_df | $_ev]"; rm -rf "$_w"
  # The guard fires on the FIRST Stop after the lease, at a fresh run of 1: three deferrals moved
  # no counter. A deferral that wrote the counter reaches the 4th block and releases instead.
  [ "$_d" = aaaH ] || return 1
  [ "$_df" = 3 ] || return 1
  [ "$_ev" = 'HANDOFF_GUARD_BLOCK (1/3) ' ]
}
# BL-641: the unknown-tool path (transcript unreadable) keyed on the session the state file names.
# The transcript is REMOVED, never emptied, so the hook's own readability test answers unknown. The
# clock is the shimmed one (+31 is 31 shimmed seconds, never a sleep), and the 4th state line is
# produced by the hook itself, so these arms read the writer and the reader together.
arm_8j() { # unreadable transcript, one session, 31s apart: the run reaches EFF_MAX and releases
  _w="$(tx_world transcript)"; rm -f "$_w/transcript.jsonl"
  _d="$(tx_seq "$_w" "$1" - S +31 S +31 S +31 S +31 S)"
  _rows="$(tx_rows "$_w")"; _fl="$(sed -n '4p' "$_w/_bmad-output/pipeline-block-state.txt" 2>/dev/null)"
  ARM_MSG="[$_d | $_rows| line4=$_fl]"; rm -rf "$_w"
  # EFF_MAX is 3: blocks at count 1, 2, 3 and the release at 4. The time-only reading resets every
  # 31s block to 1 and never releases (`bbbbb`).
  [ "$_d" = bbbab ] && [ "$_rows" = 'unknown unknown unknown unknown ' ]
}
arm_8k() { # CONTROL: a different session_id over the same unreadable transcript starts a new run
  _w="$(tx_world transcript)"; rm -f "$_w/transcript.jsonl"
  _d="$(tx_seq "$_w" "$1" - S +31 S +31 S @jy2 +31 S +31 S +31 S +31 S)"
  ARM_MSG="[$_d]"; rm -rf "$_w"
  # jy: 1 2 3 | jy2: reset to 1, 2, 3, then the release at 4 -- seven Stops, `bbb` `bbb` `a`. An
  # always-increment reading releases on the 4th Stop (the first jy2 one) instead, `bbba`.
  [ "$_d" = bbbbbba ]
}
ARMS_8="8a 8b 8c 8d 8e 8f 8g 8h 8i 8j 8k"
arm_desc() {
  case "$1" in
    8a) echo "text-only stall at 45s and 300s: blocks then BACKOFF on the 4th Stop, detail names the no-tool-call signal" ;;
    8b) echo "beat churn on the transcript path: a new tool call before every Stop 5s apart still reaches BACKOFF, closed by the 30s arm" ;;
    8c) echo "multi-skill progress: a new tool call before every Stop 45s apart blocks 9 times at 1/3, rows 'yes' and never 'no'" ;;
    8d) echo "a two-line (old hook) state file falls back to the time test: resets to 1, row 'unknown'; a three-line one continues" ;;
    8e) echo "a changed session_id over the same transcript reads as a tool call ('yes'); the same session reads 'no'" ;;
    8f) echo "CLAUDE_CODE_STOP_HOOK_BLOCK_CAP clamps EFF_MAX: 1 -> ba, 0 -> bbba, 2 -> bba" ;;
    8g) echo "a slow text-only handoff-guard run releases after EFF_MAX, each row carrying the tool-call line" ;;
    8h) echo "the same run with the pause flag DOWN releases by the 4th Stop via a 'Handoff guard:' BACKOFF, never more than 3 blocks in a row over 9 Stops" ;;
    8j) echo "an unreadable transcript in one session, 31s apart, blocks three times and releases on the 4th Stop (never resets on the gap)" ;;
    8k) echo "control: a changed session_id over the unreadable transcript resets the run to 1 (the release comes two Stops after the change, not before)" ;;
    8i) echo "three Stops on handoff.md step 1's live beat are deferred (aaa) and the first Stop past the lease is the guard's block at 1/3 (H)" ;;
  esac
}
# EVERY ARM OF SECTION 8 IS A CONCURRENT JOB. Each builds its own worlds, so no two share a file;
# each job writes its verdict lines to its own file,
# and the collector at the end of section 8 prints and counts them in dispatch order after
# `wait`. Serially the two sections took this fixture from ~3s to ~43s. A `bad` inside a
# subshell cannot move `fails`, so the collector counts FAIL lines from the files, fails an
# EMPTY file (a job that died before printing scored nothing), and fails a dispatch count other
# than JOBS_WANT (a job line that was lost).
JOBS="$(mktemp -d "${TMPDIR:-/tmp}/join-yield-jobs-XXXXXX")"
JOB_N=0
job() { JOB_N=$((JOB_N + 1)); ( "$@" ) > "$JOBS/verdict.$JOB_N" 2>&1 & }
arm_job() { # arm_job <arm> <hook> <label-prefix>
  if "arm_$1" "$2"; then ok "$3$1 $(arm_desc "$1")"
  else bad "$3$1 $(arm_desc "$1") -- got $ARM_MSG"; fi
}
for _a in $ARMS_8; do job arm_job "$_a" "$STOP_HOOK" ""; done

wait
set -- $ARMS_8; N_ARMS=$#
JOBS_WANT=$N_ARMS
_i=0
while [ "$_i" -lt "$JOB_N" ]; do
  _i=$((_i + 1)); _vf="$JOBS/verdict.$_i"
  if [ ! -s "$_vf" ]; then bad "job $_i produced no verdict -- its subshell died, so nothing was scored"; continue; fi
  cat "$_vf"
  _nf="$(grep -c '^  FAIL' "$_vf")" || _nf=0
  fails=$((fails + _nf))
  _no="$(grep -c '^  ok    ' "$_vf")" || _no=0
  oks=$((oks + _no))
done
[ "$JOB_N" -eq "$JOBS_WANT" ] || bad "section 8 dispatched $JOB_N jobs, expected $JOBS_WANT -- a job line was lost"
rm -rf "$JOBS"

# --- the cli cells (cells.decl): the hook started as a PROGRAM once per distinct outcome -----------------------
# The hook exits 0 on every path; its outcomes here are a block verdict on stdout and a silent allow (a live beat
# yields). Each is started as FXCELL=<id> bash "$STOP_HOOK" on a seeded world and compared with the in-process call on
# another copy of it: stdout, stderr, exit and the world's tree (timestamps, epochs and the copy's path normalised).
# Each cell asserts its own outcome, so two runs that both did nothing cannot read as equal.
EQ="$JY_RUN/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir $EQ" >&2; exit 2; }
proj_sig() { # <dir> -> the tree's file list and contents, timestamps, epochs and the dir path normalised
  ( cd "$1" && find . -type f | sort | while read -r f; do printf '== %s\n' "$f"; cat "$f"; done ) \
    | sed -E -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z?/TS/g' -e 's/^TS [0-9a-f]{16}$/TS NONCE/' -e 's/[0-9]{10}/EPOCH/g' -e "s|$1|DIR|g"
}
cli_cell() { # <id> <seed-case> <outcome test on $EQ/<id>/cl.out> <outcome words>
  local id="$1" ip="$EQ/$1/ip" cl="$EQ/$1/cl" w
  w="$(bash "$HERE/seed.sh" "$2")" && mkdir -p "$EQ/$id" && cp -R "$w" "$ip" && cp -R "$w" "$cl" || { bad "$id: could not seed the world"; return; }
  rm -rf "$w"
  printf '{"session_id":"t","transcript_path":""}' | CLAUDE_PROJECT_DIR="$ip" inproc_run "$STOP_HOOK" hkcont_main > "$EQ/$id/ip.out" 2> "$EQ/$id/ip.err"; echo "$?" > "$EQ/$id/ip.rc"
  printf '{"session_id":"t","transcript_path":""}' | CLAUDE_PROJECT_DIR="$cl" FXCELL="$id" bash "$STOP_HOOK" > "$EQ/$id/cl.out" 2> "$EQ/$id/cl.err"; echo "$?" > "$EQ/$id/cl.rc"
  proj_sig "$ip" > "$EQ/$id/ip.sig"; proj_sig "$cl" > "$EQ/$id/cl.sig"
  if cmp -s "$EQ/$id/ip.out" "$EQ/$id/cl.out" && cmp -s "$EQ/$id/ip.err" "$EQ/$id/cl.err" && cmp -s "$EQ/$id/ip.rc" "$EQ/$id/cl.rc" \
     && cmp -s "$EQ/$id/ip.sig" "$EQ/$id/cl.sig" && [ "$(cat "$EQ/$id/cl.rc")" = 0 ] && [ -s "$EQ/$id/cl.sig" ] && eval "$3"; then
    ok "$id: the program $4 exactly as the in-process call does (stdout, stderr, exit 0 and the world's tree)"
  else
    bad "$id: the program and the in-process call differ, or the outcome is not: $4"
  fi
}
cli_cell cli-block no-marker 'blocked "$(cat "$EQ/$id/cl.out")"' "blocks the stop with a decision on stdout"
cli_cell cli-yield live-marker '[ ! -s "$EQ/$id/cl.out" ] && fired_live "$cl"' "allows the stop silently and logs ALLOWED_BY_LIVE_BEAT"

echo
report_end implementation-join-yield
