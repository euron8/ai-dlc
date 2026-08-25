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
# the fixture cannot spend 30s per arm, and `date` is not injectable into the
# hook. It rewrites the hook's own OUTPUT, never its input grammar.
age_state() {
  _sf="$1/_bmad-output/pipeline-block-state.txt"; [ -f "$_sf" ] || return 0
  _t="$(sed -n '1p' "$_sf")"; _c="$(sed -n '2p' "$_sf")"
  printf '%s\n%s\n' "$(( _t - 100 ))" "$_c" > "$_sf"
}
# Drive one event sequence: B = block turn (no beat), L = live-beat turn,
# G = the previous beat consumed real time. Echoes the decision sequence.
drive_seq() {
  _w="$1"; shift
  for _e in "$@"; do
    case "$_e" in
      G) age_state "$_w"; continue ;;
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
W="$(bash "$HERE/seed.sh" sequence)"; SEQ="$(drive_seq "$W" B L B L B L B L B)"
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

echo
if [ "$fails" -eq 0 ]; then echo "implementation-join-yield: PASS"; exit 0; fi
echo "implementation-join-yield: $fails assertion(s) FAILED" >&2
exit 1
