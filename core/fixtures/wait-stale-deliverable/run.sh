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
MUTDIR="$(mktemp -d 2>/dev/null || mktemp -d -t wait-mutants)"
trap 'rm -f "$BEATOUT"; rm -rf "$MUTDIR"' EXIT
beat_with() { # <subject> <work> [extra args...] -> writes $BEATOUT; sets RC and OUT
  local subj="$1" w="$2"; shift 2
  ( cd "$w" && env AI_DLC_WAIT_BEAT_SECS=4 \
                   AI_DLC_WAIT_POLL_SECS=1 \
                   AI_DLC_WAIT_MARGIN_SECS=1 \
                   AI_DLC_MAX_WAIT_BEATS=6 \
    bash "$subj" "$@" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}
beat() { local w="$1"; shift; beat_with "$SUBJ" "$w" "$@"; }

# ---------------------------------------------------------------------------
# MUTANTS ARE BUILT AS COPIES, AND THE SUBJECT IS NEVER EDITED.
# A mutation proof carried as a prose note is a forgeable evidence cell: it can be
# written without the run, and nothing in the suite re-checks it when the code it
# describes moves. So the mutants live here, and section 14 runs them.
#
# Mutating a COPY is also the only reason the proof is safe to re-run. Mutating the
# shipped script in place needs a revert, and the obvious revert -- `git checkout --
# <file>` -- silently destroys any uncommitted work in that same file. That is not
# hypothetical; it is how this fixture's own mutation evidence was first produced,
# twice, and recovered by luck rather than design. There is nothing to revert here.
#
# `cmp -s` is the anti-vacuity guard, and it is the point of the helper. A mutant
# whose pattern no longer matches produces a byte-identical copy, the "wrong
# behaviour" assertion then runs against the UNMUTATED subject, and it passes --
# reporting a proof that never happened. Renaming the code a mutant targets must
# break this fixture LOUDLY (exit 2, fixture-broken) rather than quietly turn its
# assertion green.
# ---------------------------------------------------------------------------
# Sets $MUT rather than printing it, and that is load-bearing twice over. `M="$(
# mutant ...)"` would run this in a SUBSHELL, so its `exit 2` would kill only that
# subshell: a mutant that matched nothing would leave M empty, `bash ""` would exit
# 127, and a "the subject now misbehaves" assertion phrased as `!= 64` would read
# 127 and go GREEN. That is not hypothetical -- it is what the first draft of this
# section did. Separate `local` lines for the same family of reason: bash creates
# every name on a single `local` before assigning any of them, so `local a=$1 b=$a`
# leaves b empty (and trips `set -u`).
MUT=""
mutant() { # <name> <sed-expr> -> sets $MUT to the mutant's path
  local name="$1"
  local expr="$2"
  local m="$MUTDIR/$name.sh"
  sed "$expr" "$SUBJ" > "$m" || { echo "FIXTURE ERROR: sed failed for mutant '$name'" >&2; exit 2; }
  if cmp -s "$SUBJ" "$m"; then
    echo "FIXTURE ERROR: mutant '$name' matched nothing -- the code it targets was" >&2
    echo "  renamed or removed. Re-aim the mutation; do NOT delete the assertion." >&2
    exit 2
  fi
  MUT="$m"
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

# --- 10. an exhausted sequence with evidence of work is EXTENDED, not declared ---
# The clock says the teammate is dead; the filesystem says it wrote a file during
# the last beat. Both prior fixes for this failure only moved the clock, and S298
# then produced a legitimate 62-minute dispatch -- past even the raised ceiling.
# The message alone is not the assertion: `.grants` is checked, because a subject
# that printed PROGRESS and exhausted anyway would still re-dispatch a live
# teammate while reading as fixed.
W="$( bash "$SEED" progress-extends )"
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"
beat "$W" --progress-path wt
if [ "$RC" -eq 0 ] && ! grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "progress-extends: no non-delivery while the teammate is demonstrably working"
else bad "progress-extends: rc $RC with NON-DELIVERY — a live teammate is re-dispatched on a clock"; fi
if grep -q '^PROGRESS' "$BEATOUT"; then
  ok "progress-extends: stdout names PROGRESS — the lead learns why not to re-dispatch"
else bad "progress-extends: no PROGRESS line; the extension is invisible to the lead"; fi
if [ "$(cat "$W/_bmad-output/.wait-beats/${KEY}.grants" 2>/dev/null)" = "1" ]; then
  ok "progress-extends: one grant charged — the extension is counted, not free"
else bad "progress-extends: .grants not 1 — an uncounted extension is an unbounded wait"; fi
rm -rf "$W"

# The mutation proof for cases 10-13 is section 14, which RUNS it.

# --- 11. ...but the extension is BOUNDED. This is the case that keeps Check C ----
# true. Same evidence of work as case 10, every grant already spent. If this ever
# goes green-with-rc-0 the join can be held open forever by a teammate that writes
# and never delivers, and SKILL.md's Rule 26(c) claim that this script "can commit
# neither" failure becomes false with nothing to say so.
W="$( bash "$SEED" progress-bounded )"
beat "$W" --progress-path wt
if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "progress-bounded: rc 1 once the grants are spent — the wait still ends"
else bad "progress-bounded: rc $RC — progress with no cap is an unbounded wait (Rule 29, Check C)"; fi
case "$OUT" in
  *"progress grants are spent"*) ok "progress-bounded: the NOTE says why, so the lead is not left guessing" ;;
  *) bad "progress-bounded: non-delivery on a working teammate with no explanation" ;;
esac
if [ "$(cat "$W/_bmad-output/.wait-beats/${KEY}.grants" 2>/dev/null)" = "6" ]; then
  ok "progress-bounded: grant counter held at the cap"
else bad "progress-bounded: grant counter moved past the cap"; fi
rm -rf "$W"

# --- 12. machinery heartbeats in the watched tree are not evidence of work -------
# A teammate worktree carries its own `_bmad-output/`. Its `.wait-beats/` counters
# and `.beat-inflight` keep ticking whether or not the teammate is alive, and they
# are NOT this run's state dir, so the argument guard in case 13 cannot see them.
# Only the prune can. Without it, pointing at a worktree grants forever.
W="$( bash "$SEED" progress-ignores-own-state )"
beat "$W" --progress-path wt
if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "progress-ignores-own-state: wait-beat machinery does not count as work"
else bad "progress-ignores-own-state: rc $RC — the beat is reading its own heartbeat as the teammate's progress"; fi
if grep -q '^PROGRESS' "$BEATOUT"; then
  bad "progress-ignores-own-state: granted on .beat-inflight/.wait-beats churn alone"
else ok "progress-ignores-own-state: no PROGRESS line"; fi
rm -rf "$W"

# --- 13. the two ways this check could silently never fire ----------------------
# Both are argument errors, not runtime behaviour, because both produce a subject
# that runs clean forever while enforcing nothing. The CONTROL matters as much as
# the rejections: a subject that refused every --progress-path would satisfy the
# three exit-64 assertions and be entirely useless.
W="$( bash "$SEED" progress-guards )"
guard() { ( cd "$W" && env AI_DLC_WAIT_BEAT_SECS=4 AI_DLC_WAIT_POLL_SECS=1 \
                           AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 \
              bash "$SUBJ" --progress-path "$1" deliv.md ) >/dev/null 2>&1; echo $?; }
if [ "$(guard _bmad-output)" = "64" ]; then
  ok "progress-guards: the state dir is refused — it is written by this beat every poll"
else bad "progress-guards: --progress-path _bmad-output accepted; progress is then always true and NON-DELIVERY can never fire"; fi
if [ "$(guard .)" = "64" ]; then
  ok "progress-guards: an ANCESTOR of the state dir is refused too"
else bad "progress-guards: --progress-path . accepted; it contains the state dir, same defect one level up"; fi
if [ "$(guard no-such-dir)" = "64" ]; then
  ok "progress-guards: a nonexistent path is refused — it could never show work"
else bad "progress-guards: a typo'd progress path is accepted and silently grants nothing, ever"; fi
if [ "$(guard wt)" != "64" ]; then
  ok "progress-guards: CONTROL — a real worktree path is accepted"
else bad "progress-guards: every --progress-path is rejected; the flag does nothing"; fi
rm -rf "$W"

# --- 14. the mutation proof, executed ------------------------------------------
# Each mutant removes ONE mechanism and asserts the subject then does the WRONG
# thing on the seed that mechanism exists for. That is a stronger claim than "the
# fixture reds": it names the behaviour the mechanism buys, so a reader can see what
# would ship without it. Every mutant is a copy; the subject is untouched throughout.
#
# The `.progress` mark: these reuse the same seeds as cases 10-13, which age the
# mark deliberately. See the seed file -- without that, `progressed_since` has
# nothing to compare against on its first call and every mutant looks equally dead.

mutant grant-cap 's/ \&\& \[ "\$g" -lt "\$MAX_BEATS" \]//'
M="$MUT"
W="$( bash "$SEED" progress-bounded )"
beat_with "$M" "$W" --progress-path wt
if [ "$RC" -eq 0 ]; then
  ok "MUTANT grant-cap: without the cap a spent-grant join keeps extending — an unbounded wait"
else bad "MUTANT grant-cap: still rc $RC with the cap removed; the cap is not what bounds the extension"; fi
rm -rf "$W"

# Two prunes, mutated separately. Lumping them proves only that ONE of the two is
# load-bearing, and the seed ticks both `.wait-beats/<key>` and `.beat-inflight`.
mutant unprune-wait-beats 's/-o -name \.wait-beats/-o -name .no-such-name/'
M="$MUT"
W="$( bash "$SEED" progress-ignores-own-state )"
beat_with "$M" "$W" --progress-path wt
if [ "$RC" -eq 0 ] && grep -q '^PROGRESS' "$BEATOUT"; then
  ok "MUTANT unprune-wait-beats: a teammate's own beat counters then read as work"
else bad "MUTANT unprune-wait-beats: rc $RC without the .wait-beats prune; the prune is not what excludes them"; fi
rm -rf "$W"

mutant unexclude-beat-inflight "s/! -name '\.beat-inflight' //"
M="$MUT"
W="$( bash "$SEED" progress-ignores-own-state )"
beat_with "$M" "$W" --progress-path wt
if [ "$RC" -eq 0 ] && grep -q '^PROGRESS' "$BEATOUT"; then
  ok "MUTANT unexclude-beat-inflight: a heartbeat marker then reads as work"
else bad "MUTANT unexclude-beat-inflight: rc $RC without the exclusion; it is not what excludes the marker"; fi
rm -rf "$W"

# Neutering SD_ABS rather than the comparison: the guard reads `[ -n "$SD_ABS" ]`,
# so an unresolvable state dir disables it wholesale. One line, unambiguously aimed.
mutant state-dir-guard 's/^  SD_ABS="\$(abs_of "\$STATE_DIR")"$/  SD_ABS=""/'
M="$MUT"
W="$( bash "$SEED" progress-guards )"
beat_with "$M" "$W" --progress-path _bmad-output
# `-eq 0`, not `-ne 64`: a mutant that failed to build exits 127, and `-ne 64`
# would read that as proof. The assertion has to name the outcome it expects.
if [ "$RC" -eq 0 ]; then
  ok "MUTANT state-dir-guard: _bmad-output is then accepted — progress becomes permanently true"
else bad "MUTANT state-dir-guard: rc $RC, expected a normal beat; the guard is not what rejects it"; fi
rm -rf "$W"

mutant path-exists-check 's/\[ -e "\$1" \] ||/[ 1 ] ||/'
M="$MUT"
W="$( bash "$SEED" progress-guards )"
beat_with "$M" "$W" --progress-path no-such-dir
if [ "$RC" -eq 0 ]; then
  ok "MUTANT path-exists-check: a typo'd path is then accepted and grants nothing, forever"
else bad "MUTANT path-exists-check: rc $RC, expected a normal beat; the check is not what rejects it"; fi
rm -rf "$W"

mutant progress-sampling '/progressed_since "\$pg" \&\& PROGRESSED=1/d'
M="$MUT"
W="$( bash "$SEED" progress-extends )"
beat_with "$M" "$W" --progress-path wt
if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "MUTANT progress-sampling: a demonstrably working teammate is declared non-delivered"
else bad "MUTANT progress-sampling: rc $RC without sampling; the grant is reachable by some other route"; fi
rm -rf "$W"

# The other half of the claim: none of the six changes the FLAGLESS path. Asserted
# rather than described, because "strictly additive" is exactly the sort of promise
# that quietly stops being true. `exhausted` is the case with the most to lose --
# it is the one state that still exits nonzero.
for mname in grant-cap unprune-wait-beats unexclude-beat-inflight state-dir-guard \
             path-exists-check progress-sampling; do
  W="$( bash "$SEED" exhausted )"
  beat_with "$MUTDIR/$mname.sh" "$W"
  if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
    ok "MUTANT $mname: the flagless path is untouched (exhausted still rc 1)"
  else bad "MUTANT $mname: rc $RC on a flagless join — this mutant reaches code the default path uses"; fi
  rm -rf "$W"
done

if [ "$fails" -eq 0 ]; then
  echo "wait-stale-deliverable: PASS"
  exit 0
fi
echo "wait-stale-deliverable: ${fails} assertion(s) FAILED" >&2
exit 1
