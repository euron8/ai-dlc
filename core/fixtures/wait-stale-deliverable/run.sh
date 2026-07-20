#!/usr/bin/env bash
# wait-stale-deliverable — the bounded join must not accept a file that predates
# it, and must still arm the yield while it waits.
#
# THE DEFECT THIS ADDRESSES. `wait-for-deliverable.sh` tested delivery with
# `[ -s "$t" ]`. A deliverable path reused across sprints therefore reported
# DELIVERED in under a second against the PREVIOUS sprint's file. Observed live: a
# bug-investigation join landed on a 41KB analysis committed three sprints earlier
# and the lead caught it only by reading a date line in the body. A join that
# always succeeds reads exactly like a join that worked — nothing downstream ever
# re-examines it, which is why this is a silent wrong answer and not a stall.
#
# THE SECOND-ORDER FAILURE. The instant-DELIVERED path returned before the script
# ever reached its sleep, so `.beat-inflight` was never written. That marker is the
# ONLY thing Stop-hook Check 2b accepts as permission to end a turn mid-join, so
# the lead could not yield, hand-rolled an mtime loop that writes no marker either,
# and fell back to foreground polling — the exact cost this script exists to
# eliminate. Hence `stale-marker`: fixing the predicate must also restore the yield.
#
# THE TRAP. `--since` cannot be the authority. A lead writes `dispatched-at`
# ROUNDED (observed: 23:30:00Z for a 23:29:50 dispatch — ten seconds into the
# FUTURE), and a future threshold is absorbing: the teammate's file is never
# rewritten, so every later beat re-reads the same mtime and the join walks to a
# non-delivery on a complete artifact. `since-clamp` is that scenario; it passes
# only because the subject clamps --since to `now`.
set -uo pipefail

# HERMETIC — scrub the operator's tuning BEFORE this fixture sets its own (I10).
# Order is load-bearing here in a way it is not for hook fixtures: this one tunes
# AI_DLC_* per invocation, so a scrub placed later would wipe its own settings.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SUBJ="$(pick "$HERE/../../scripts/wait-for-deliverable.sh" \
             "$HERE/../../../scripts/wait-for-deliverable.sh" \
             "$HERE/../../../core/scripts/wait-for-deliverable.sh")"
[ -n "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate wait-for-deliverable.sh" >&2; exit 2; }
SEED="$HERE/seed.sh"
[ -f "$SEED" ] || { echo "FIXTURE ERROR: cannot locate seed.sh" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# A short beat keeps the suite fast. AI_DLC_WAIT_MARGIN_SECS is load-bearing and
# easy to miss: MARGIN defaults to 10, and RESERVE = max(MARGIN, POLL), so with the
# default the deadline would land in the PAST, the poll loop would break on its
# first iteration, and every timing assertion below would pass or fail by luck.
# Output goes to a file rather than command substitution: `OUT="$(beat ...)"` would
# run the function in a subshell, so the RC it sets would never reach the caller and
# every exit-code assertion would read a stale value.
BEATOUT="$(mktemp)"
trap 'rm -f "$BEATOUT"' EXIT
beat() { # <work> [extra args...] -> writes $BEATOUT; sets RC and OUT
  local w="$1"; shift
  ( cd "$w" && env AI_DLC_STEERING_BUDGET=4 \
                   AI_DLC_WAIT_POLL_SECS=1 \
                   AI_DLC_WAIT_MARGIN_SECS=1 \
                   AI_DLC_MAX_WAIT_BEATS=10 \
    bash "$SUBJ" "$@" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}

echo "wait-stale-deliverable:"

# --- 1. the headline: a file from a prior sprint is not this join's answer ------
W="$( bash "$SEED" stale )"
beat "$W"
if [ "$RC" -eq 2 ]; then ok "stale: rc 2 (WAITING), not accepted on sight"
else bad "stale: rc $RC — a 25-day-old artifact was accepted as this join's delivery"; fi
case "$OUT" in
  *DELIVERED*) bad "stale: printed DELIVERED for a file that predates the join" ;;
  *)           ok  "stale: never printed DELIVERED" ;;
esac
case "$OUT" in
  *"already had content when this join armed"*) ok "stale: NOTE names the ambiguity and --since" ;;
  *) bad "stale: no NOTE — the lead learns nothing until the sequence bound trips" ;;
esac
rm -rf "$W"

# --- 2. the yield the predicate fix must restore -------------------------------
# The marker is removed by an EXIT trap, so it only exists mid-beat: background the
# subject and poll. `kill -0` catches an exit that never wrote it at all, which is
# precisely the pre-fix behaviour.
W="$( bash "$SEED" stale-marker )"
( cd "$W" && env AI_DLC_STEERING_BUDGET=4 AI_DLC_WAIT_POLL_SECS=1 \
                 AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=10 \
    bash "$SUBJ" deliv.md >/dev/null 2>&1 ) & PID=$!
seen=0
for _ in $(seq 1 80); do
  [ -f "$W/_bmad-output/.beat-inflight" ] && { seen=1; break; }
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.1
done
wait "$PID" 2>/dev/null || true
if [ "$seen" -eq 1 ]; then ok "stale-marker: .beat-inflight live during the beat (lead may yield)"
else bad "stale-marker: no .beat-inflight — the lead cannot yield and will poll in foreground"; fi
if [ -f "$W/_bmad-output/.beat-inflight" ]; then
  bad "stale-marker: marker survived the beat — a dead beat would authorize a silent stall"
else ok "stale-marker: marker cleared on exit"; fi
rm -rf "$W"

# --- 3. the teammate's real write, landing mid-beat -----------------------------
W="$( bash "$SEED" arrives-mid-beat )"
( sleep 2; printf 'the actual answer for this sprint\n' > "$W/deliv.md" ) &
WRITER=$!
START="$(date +%s)"
beat "$W"
ELAPSED=$(( $(date +%s) - START ))
wait "$WRITER" 2>/dev/null || true
if [ "$RC" -eq 0 ]; then ok "arrives-mid-beat: rc 0 (DELIVERED) once the real write lands"
else bad "arrives-mid-beat: rc $RC — a genuine delivery was missed"; fi
# Zero elapsed means the poll loop broke on the stale file's mere presence while
# the sweep applied the fresh predicate: a beat charged, none slept.
if [ "$ELAPSED" -ge 2 ]; then ok "arrives-mid-beat: beat actually slept (${ELAPSED}s) — predicates agree"
else bad "arrives-mid-beat: returned in ${ELAPSED}s — poll loop and sweep disagree on delivery"; fi
rm -rf "$W"

# --- 4. a rounded-UP dispatch stamp must not become an unmeetable threshold -----
W="$( bash "$SEED" since-clamp )"
FUT=$(( $(date +%s) + 600 ))
( sleep 2; printf 'the actual answer for this sprint\n' > "$W/deliv.md" ) &
WRITER=$!
beat "$W" --since "$FUT"
wait "$WRITER" 2>/dev/null || true
if [ "$RC" -eq 0 ]; then ok "since-clamp: a 10-minute-future --since still accepts the real write"
else bad "since-clamp: rc $RC — --since was trusted past now, threshold is unsatisfiable"; fi
rm -rf "$W"

# --- 5. --since may pull the threshold EARLIER (the post-compaction join) -------
W="$( bash "$SEED" since-earlier )"
beat "$W"
if [ "$RC" -eq 2 ]; then ok "since-earlier: bare call waits — a pre-join file is not proof"
else bad "since-earlier: rc $RC — accepted a file written before the join armed"; fi
START="$(date +%s)"
beat "$W" --since "$(( $(date +%s) - 60 ))"
ELAPSED=$(( $(date +%s) - START ))
if [ "$RC" -eq 0 ]; then ok "since-earlier: --since in the past recovers the early delivery"
else bad "since-earlier: rc $RC — --since could not move the threshold earlier"; fi
# Also proves the fix did not turn every join into a mandatory sleep.
if [ "$ELAPSED" -le 1 ]; then ok "since-earlier: returned without sleeping"
else bad "since-earlier: slept ${ELAPSED}s on an already-satisfied join"; fi
rm -rf "$W"

# --- 6. regression guards -------------------------------------------------------
W="$( bash "$SEED" exhausted )"
beat "$W"
if [ "$RC" -eq 1 ]; then ok "exhausted: rc 1 (NON-DELIVERY) once the sequence bound is spent"
else bad "exhausted: rc $RC — the sequence bound no longer terminates the wait"; fi
rm -rf "$W"

W="$( bash "$SEED" absent )"
beat "$W"
if [ "$RC" -eq 2 ]; then ok "absent: rc 2 (WAITING) — unchanged for a path with no file"
else bad "absent: rc $RC — the ordinary absent case regressed"; fi
case "$OUT" in
  *"already had content"*) bad "absent: emitted the pre-existing NOTE for a file that never existed" ;;
  *)                       ok  "absent: no spurious NOTE" ;;
esac
rm -rf "$W"

if [ "$fails" -eq 0 ]; then
  echo "wait-stale-deliverable: PASS"
  exit 0
fi
echo "wait-stale-deliverable: ${fails} assertion(s) FAILED" >&2
exit 1
