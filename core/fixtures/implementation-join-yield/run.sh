#!/usr/bin/env bash
# implementation-join-yield — the Stop hook must let the lead YIELD while a
# backgrounded wait-beat is live (Rule 29, v0.81.0), and must STILL block a
# genuine stall.
#
# THE DEFECT THIS ADDRESSES. `ai-dlc-continue.sh` force-continues every text-only
# turn during an active pipeline (Rule 3). A lead waiting on teammates is
# therefore shoved through dozens of forced continuations per implementation
# phase (measured: 45-150/day on the reference consumer). Check 2b lets the lead
# END ITS TURN iff `scripts/wait-for-deliverable.sh` has a backgrounded beat
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
# 6. PROGRESS — a live-beat allow resets the rapid-fire counter, so a burst of
#    legitimate yields cannot trip the backoff and free a later genuine stall.
# =============================================================================
W="$(bash "$HERE/seed.sh" counter-reset)"; OUT="$(drive_stop "$W")"
if blocked "$OUT"; then bad "counter-reset: BLOCKED with a live beat"
elif [ -f "$W/_bmad-output/pipeline-block-state.txt" ]; then bad "counter-reset: the rapid-fire counter SURVIVED a live-beat allow — a yield burst can still trip the backoff"
elif fired_live "$W"; then ok "counter-reset: the live-beat allow clears the rapid-fire state (a yield is progress)"
else bad "counter-reset: the allow did not come from Check 2b"; fi
rm -rf "$W"

echo
if [ "$fails" -eq 0 ]; then echo "implementation-join-yield: PASS"; exit 0; fi
echo "implementation-join-yield: $fails assertion(s) FAILED" >&2
exit 1
