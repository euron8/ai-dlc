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
             "$HERE/../../../scripts/ai-dlc/wait-for-deliverable.sh" \
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
  ( cd "$w" && env AI_DLC_WAIT_BEAT_SECS=4 \
                   AI_DLC_WAIT_POLL_SECS=1 \
                   AI_DLC_WAIT_MARGIN_SECS=1 \
                   AI_DLC_MAX_WAIT_BEATS=6 \
    bash "$SUBJ" "$@" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}

echo "wait-stale-deliverable:"

# --- 1. the headline: a file from a prior sprint is not this join's answer ------
W="$( bash "$SEED" stale )"
beat "$W"
if [ "$RC" -eq 0 ]; then ok "stale: rc 0 (beat complete) — waiting is not a failure"
else bad "stale: rc $RC — a still-waiting beat must not exit nonzero (harness reads it as failed)"; fi
# Anchored to the per-path line, not a bare substring: the BEAT COMPLETE summary
# legitimately contains the word "DELIVERED" while reporting zero of them.
if grep -q '^DELIVERED' "$BEATOUT"; then
  bad "stale: printed DELIVERED for a file that predates the join"
else
  ok "stale: no DELIVERED line for a file that predates the join"
fi
case "$OUT" in
  *"already had content when this join armed"*) ok "stale: NOTE names the ambiguity and --since" ;;
  *) bad "stale: no NOTE — the lead learns nothing until the sequence bound trips" ;;
esac
# With WAITING no longer distinguishable by exit code, stdout is the ONLY channel
# carrying it. If these lines ever stop being printed, every outcome looks like
# rc 0 and the lead consumes a file that was never delivered.
case "$OUT" in
  *"WAITING"*) ok "stale: stdout carries WAITING — the signal the exit code no longer holds" ;;
  *) bad "stale: rc 0 and no WAITING in stdout — an undelivered join is indistinguishable from a delivered one" ;;
esac
case "$OUT" in
  *"BEAT COMPLETE -- 0 delivered, 1 still out"*) ok "stale: summary states what to consume" ;;
  *) bad "stale: no BEAT COMPLETE summary naming the counts" ;;
esac
rm -rf "$W"

# --- 2. the yield the predicate fix must restore -------------------------------
# The marker is removed by an EXIT trap, so it only exists mid-beat: background the
# subject and poll. `kill -0` catches an exit that never wrote it at all, which is
# precisely the pre-fix behaviour.
W="$( bash "$SEED" stale-marker )"
( cd "$W" && env AI_DLC_WAIT_BEAT_SECS=4 AI_DLC_WAIT_POLL_SECS=1 \
                 AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 \
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
if [ "$RC" -eq 0 ] && grep -q '^DELIVERED' "$BEATOUT"; then
  ok "arrives-mid-beat: DELIVERED once the real write lands"
else bad "arrives-mid-beat: rc $RC, no DELIVERED line — a genuine delivery was missed"; fi
# Zero elapsed means the poll loop broke on the stale file's mere presence while
# the sweep applied the fresh predicate: a beat charged, none slept.
if [ "$ELAPSED" -ge 2 ]; then ok "arrives-mid-beat: beat actually slept (${ELAPSED}s) — predicates agree"
else bad "arrives-mid-beat: returned in ${ELAPSED}s — poll loop and sweep disagree on delivery"; fi
rm -rf "$W"

# --- 4. a rounded-UP dispatch stamp must not become an unmeetable threshold -----
# MUTATION NOTE: this case reds only when BOTH guards in join_of are removed --
# `[ "$SINCE" -lt "$j_" ]` (apply --since only if it lowers) and `[ "$j_" -gt
# "$now_" ]` (never above now). Either alone defeats a future stamp, so mutating one
# leaves the case green. That is redundancy, not vacuity: verified by removing both,
# which reds it. Do not conclude this assertion is dead from a single-line mutation.
W="$( bash "$SEED" since-clamp )"
FUT=$(( $(date +%s) + 600 ))
( sleep 2; printf 'the actual answer for this sprint\n' > "$W/deliv.md" ) &
WRITER=$!
beat "$W" --since "$FUT"
wait "$WRITER" 2>/dev/null || true
if [ "$RC" -eq 0 ] && grep -q '^DELIVERED' "$BEATOUT"; then
  ok "since-clamp: a 10-minute-future --since still accepts the real write"
else bad "since-clamp: no DELIVERED line — --since was trusted past now, threshold unsatisfiable"; fi
rm -rf "$W"

# --- 5. --since may pull the threshold EARLIER (the post-compaction join) -------
W="$( bash "$SEED" since-earlier )"
beat "$W"
if [ "$RC" -eq 0 ] && grep -q '^WAITING' "$BEATOUT" && ! grep -q '^DELIVERED' "$BEATOUT"; then
  ok "since-earlier: bare call waits — a pre-join file is not proof, and waiting is not a failure"
else bad "since-earlier: rc $RC — expected a WAITING beat with no DELIVERED line"; fi
START="$(date +%s)"
beat "$W" --since "$(( $(date +%s) - 60 ))"
ELAPSED=$(( $(date +%s) - START ))
if [ "$RC" -eq 0 ] && grep -q '^DELIVERED' "$BEATOUT"; then
  ok "since-earlier: --since in the past recovers the early delivery"
else bad "since-earlier: no DELIVERED line — --since could not move the threshold earlier"; fi
# Also proves the fix did not turn every join into a mandatory sleep.
if [ "$ELAPSED" -le 1 ]; then ok "since-earlier: returned without sleeping"
else bad "since-earlier: slept ${ELAPSED}s on an already-satisfied join"; fi
rm -rf "$W"

# --- 6. regression guards -------------------------------------------------------
W="$( bash "$SEED" exhausted )"
beat "$W"
# The ONE state that still exits nonzero. Nonzero is now reserved for "needs a
# decision", so if this ever returns 0 a real non-delivery becomes invisible --
# and the whole point of retiring exit 2 was to stop drowning this signal.
if [ "$RC" -eq 1 ]; then ok "exhausted: rc 1 (NON-DELIVERY) — the one loud state, still loud"
else bad "exhausted: rc $RC — a genuine non-delivery no longer exits nonzero"; fi
case "$OUT" in
  *"NON-DELIVERY"*) ok "exhausted: stdout names NON-DELIVERY" ;;
  *) bad "exhausted: no NON-DELIVERY in stdout" ;;
esac
rm -rf "$W"

W="$( bash "$SEED" absent )"
beat "$W"
if [ "$RC" -eq 0 ] && grep -q '^WAITING' "$BEATOUT"; then
  ok "absent: beat completes with WAITING for a path with no file"
else bad "absent: rc $RC — the ordinary absent case regressed"; fi
case "$OUT" in
  *"already had content"*) bad "absent: emitted the pre-existing NOTE for a file that never existed" ;;
  *)                       ok  "absent: no spurious NOTE" ;;
esac
rm -rf "$W"

# --- 7. the counter is scoped to the bound it was counted against ---------------
# `counter-bound-reset` and `exhausted` are the same tree with one byte different:
# `.bound`. That byte is the whole mechanism, and the pair is what makes each
# assertion non-vacuous — deleting the self-heal reds ONLY this case, and a
# self-heal that wiped unconditionally would red ONLY `exhausted`.
W="$( bash "$SEED" counter-bound-reset )"
beat "$W"
if [ "$RC" -eq 0 ] && ! grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "counter-bound-reset: a counter spent against a DIFFERENT bound does not exhaust"
else bad "counter-bound-reset: rc $RC, NON-DELIVERY on a stale counter — a live teammate is re-dispatched on the first beat after a retune"; fi
if [ "$(cat "$W/_bmad-output/.wait-beats/.bound" 2>/dev/null)" = "6" ]; then
  ok "counter-bound-reset: .bound rewritten to the active bound"
else bad "counter-bound-reset: .bound not rewritten — the wipe repeats on every call, so no join can ever accumulate beats"; fi
rm -rf "$W"

# --- 8. the beat quantum is NOT the steering budget ------------------------------
# One env var carried both meanings until v0.167.0: the FOREGROUND gag bound
# (validate-steering-budget.sh Check A) and this BACKGROUNDED beat's sleep. The
# merge is invisible in normal operation — both are just "a number of seconds" —
# so it is asserted from both sides. Forward: the quantum alone decides the sleep.
W="$( bash "$SEED" knob-split-forward )"
START="$(date +%s)"
( cd "$W" && env AI_DLC_WAIT_BEAT_SECS=3 AI_DLC_STEERING_BUDGET=30 \
                 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
                 AI_DLC_MAX_WAIT_BEATS=6 \
    bash "$SUBJ" deliv.md >/dev/null 2>&1 ) || true
ELAPSED=$(( $(date +%s) - START ))
if [ "$ELAPSED" -le 10 ]; then
  ok "knob-split-forward: quantum 3s honoured (${ELAPSED}s) with STEERING_BUDGET=30 ignored"
else bad "knob-split-forward: slept ${ELAPSED}s — the beat is reading AI_DLC_STEERING_BUDGET again"; fi
rm -rf "$W"

# Reverse: the steering budget cannot SHORTEN the beat either. Without this arm an
# alias in the other direction (STEERING_BUDGET winning when both are set) still
# passes the forward case whenever the budget happens to be the smaller number.
W="$( bash "$SEED" knob-split-reverse )"
START="$(date +%s)"
( cd "$W" && env AI_DLC_WAIT_BEAT_SECS=8 AI_DLC_STEERING_BUDGET=3 \
                 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
                 AI_DLC_MAX_WAIT_BEATS=6 \
    bash "$SUBJ" deliv.md >/dev/null 2>&1 ) || true
ELAPSED=$(( $(date +%s) - START ))
if [ "$ELAPSED" -ge 6 ]; then
  ok "knob-split-reverse: quantum 8s honoured (${ELAPSED}s) with STEERING_BUDGET=3 ignored"
else bad "knob-split-reverse: returned in ${ELAPSED}s — AI_DLC_STEERING_BUDGET is truncating the beat"; fi
rm -rf "$W"

# --- 9. the marker is a LEASE, not the beat's end time ---------------------------
# Stop-hook Check 2b authorizes the lead's yield for as long as `.beat-inflight`
# holds a future epoch. Written ONCE with the beat's end time, a SIGKILLed beat
# (no EXIT trap) leaves that authorization standing for the whole remaining
# quantum with nothing alive to re-invoke the lead — a dead window that grows with
# the quantum, which is exactly what raising it to 600s would have multiplied.
# Re-stamped every poll, the lease expires ~3 polls after the beat dies.
W="$( bash "$SEED" marker-goes-stale )"
( cd "$W" && env AI_DLC_WAIT_BEAT_SECS=60 AI_DLC_WAIT_POLL_SECS=1 \
                 AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 \
    bash "$SUBJ" deliv.md >/dev/null 2>&1 ) & PID=$!
MARKER="$W/_bmad-output/.beat-inflight"
for _ in $(seq 1 100); do
  [ -s "$MARKER" ] && break
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.1
done
# SIGKILL the whole process group the subshell heads, so the trap cannot run --
# the point is to leave the marker exactly as a crashed beat would.
kill -9 -"$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
LEASE="$(cat "$MARKER" 2>/dev/null || echo '')"
case "$LEASE" in
  ''|*[!0-9]*) bad "marker-goes-stale: marker absent or non-numeric after SIGKILL — cannot tell a lease from a promise" ;;
  *)
    SLACK=$(( LEASE - $(date +%s) ))
    if [ "$SLACK" -le 10 ]; then
      ok "marker-goes-stale: dead beat's lease expires in ${SLACK}s, not the rest of the quantum"
    else
      bad "marker-goes-stale: lease still ${SLACK}s out — the marker holds the beat's END time, so a crashed beat authorizes a silent stall for the whole quantum"
    fi ;;
esac
rm -rf "$W"

if [ "$fails" -eq 0 ]; then
  echo "wait-stale-deliverable: PASS"
  exit 0
fi
echo "wait-stale-deliverable: ${fails} assertion(s) FAILED" >&2
exit 1
