#!/usr/bin/env bash
# wait-for-deliverable.sh -- Rule 29's bounded file-wait beat, as a command.
#
# WHY THIS EXISTS. Rule 29 is right that a teammate's DELIVERABLE FILE is the
# handle: `Agent` returns an `agent_id` that `TaskOutput` will not take, and a
# `Skill` spawn returns no handle at all, but both deliver by file (Rule 20).
# What Rule 29 gave the lead, though, was a shell SNIPPET to retype:
#
#     for i in $(seq 1 11); do [ -s "$f" ] && exit 0; sleep 10; done
#
# Measured on the reference consumer's S289 implementation phase: the lead
# retyped that loop 75 times, at ~170 tokens of tool-call parameter each --
# ~13k resident tokens spent re-authoring a fixed procedure. Worse, a retyped
# loop is a loop that can be typed WRONG, and Rule 29's Check C (sequence bound)
# existed only to police handwritten loops after the fact.
#
# So: one call site, and the two bounds are enforced HERE, not trusted to the
# caller.
#
#   THE CALL BOUND  -- this script never runs longer than the steering budget.
#                      Every invocation is ONE beat and returns inside it, so a
#                      queued operator message lands at the next tool boundary.
#   THE SEQUENCE BOUND -- beats are COUNTED across calls in a sidecar. At
#                      max_wait_beats the script declares Rule 20 non-delivery.
#                      An unbounded wait is a hang, not a gag (Rule 29).
#
# WAIT ON A WHOLE WAVE IN ONE BEAT. Pass every deliverable you are joining:
#
#     scripts/ai-dlc/wait-for-deliverable.sh docs/reviews/a.md docs/reviews/b.md ...
#
# All paths are polled inside the SAME beat, concurrently. This is the point:
# a wave of three teammates joined as three separate calls is 3 x 110s of
# serialized wall clock, and a lead told to make one call per teammate will
# instead chain them into a single Bash call -- which is the identical failure
# in a new costume. v0.50.0 shipped without this and the consumer did exactly
# that within the hour: `wait a.md; wait b.md` in one call, 2 x 110s against a
# 120s budget, harness-backgrounded at the cap, both verdicts lost to a file it
# never read. The loop goes in the beat count, never inside the call -- and
# neither does a second beat.
#
# WHY MTIME, NOT PRESENCE. Delivery is "non-empty AND written since this join
# armed" -- not merely "non-empty". A presence-only test cannot tell a teammate's
# answer from the PREVIOUS sprint's file sitting at the same path, and it reports
# the stale one as DELIVERED in under a second. That is not a stall the lead can
# notice; it is a silent wrong answer that gets consumed as this sprint's input.
# It happened: a bug-investigation join landed on a 41KB analysis from three
# sprints earlier, and the lead caught it only by reading a date line in the body.
#
# Note the asymmetry the old predicate got backwards. This script's counter logic
# below is careful about false NON-DELIVERY (it re-dispatches a live teammate --
# loud, bounded, and a retro finding). False DELIVERY is worse: nothing downstream
# ever re-examines it. So when the two cannot be told apart, we wait.
#
# The join epoch is captured HERE, at arming, not taken from the caller. A lead
# writes `dispatched-at` into the snapshot ROUNDED (observed: 23:30:00Z recorded
# for a 23:29:50 dispatch -- ten seconds into the future). A future threshold is an
# ABSORBING failure: the teammate's file is never rewritten, so every later beat
# re-reads the same mtime, the counter walks to max_wait_beats, and the script
# declares non-delivery on a complete artifact. --since may therefore only move the
# threshold EARLIER (see the clamp at join_of), never later.
#
# LIMIT -- mtime is a heuristic, not a proof. `git checkout`, a branch switch,
# `stash pop`, and a fresh clone all stamp tracked files with the current time, so
# a stale artifact can still look fresh. The structural fix is a deliverable path
# that CANNOT collide: the nonce'd and sprint-stamped paths this pipeline already
# uses elsewhere (`s<N>-...`, `<nonce>.verdict.json`) are immune by construction.
# The collision above happened on a lead-invented UNSTAMPED path. This test is the
# belt for paths that escaped that discipline.
#
# USAGE
#   scripts/ai-dlc/wait-for-deliverable.sh <path> [<path>...] [--reset] [--quiet]
#                                   [--since <epoch|ISO8601>]
#
# EXIT CODES
#   0  BEAT COMPLETE  the beat ran and returned. Read stdout for per-path status:
#                     `DELIVERED <path>` / `WAITING <path>`, then the BEAT COMPLETE
#                     summary line. Consume ONLY the delivered paths.
#   1  NON-DELIVERY   a path exhausted max_wait_beats. Rule 20 non-delivery:
#                     re-dispatch ONCE (with --reset), then HARD_BLOCK.
#
# WHY WAITING IS NOT NONZERO. A join that is still waiting is the ordinary case --
# it is what nine of every ten beats report. The harness treats a nonzero exit from
# a BACKGROUNDED command as a failure and injects `<status>failed</status>` into
# the lead's context, so the old `exit 2` announced a failure roughly every two
# minutes for the entire life of every healthy join. That is not merely noise: a
# lead that reads an attempt as an outcome re-dispatches live teammates (it has
# happened), and a real non-delivery drowns in the false ones. Nonzero is now
# reserved for the one state that genuinely needs a decision. The delivered/waiting
# distinction moved to stdout, which the lead had to read anyway -- an exit code
# could never say WHICH path in a wave was still out.
#
# ENV
#   AI_DLC_STEERING_BUDGET   seconds a beat may take        (default 120)
#   AI_DLC_WAIT_POLL_SECS    seconds between polls          (default 10)
#   AI_DLC_MAX_WAIT_BEATS    beats before non-delivery      (default 10)
#   AI_DLC_WAIT_MARGIN_SECS  reserve held back from budget  (default 10)
#   AI_DLC_STATE_DIR         state dir                      (default _bmad-output)

set -u

BUDGET="${AI_DLC_STEERING_BUDGET:-120}"
POLL="${AI_DLC_WAIT_POLL_SECS:-10}"
MAX_BEATS="${AI_DLC_MAX_WAIT_BEATS:-10}"
STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"
MARGIN="${AI_DLC_WAIT_MARGIN_SECS:-10}"

QUIET=0
RESET=0
TARGETS=""
SINCE=""

# ---------------------------------------------------------------------------
# Platform probes, done ONCE. `stat` and `date` split BSD/GNU on exactly the two
# things this script needs, and probing per poll would re-fork them every 10s for
# the life of a 20-minute join.
# ---------------------------------------------------------------------------
if stat -f "%m" . >/dev/null 2>&1; then STAT_FLAVOR="bsd"; else STAT_FLAVOR="gnu"; fi

mtime_of() {  # epoch of $1's last write, or 0 if it cannot be read
  if [ "$STAT_FLAVOR" = "bsd" ]; then
    stat -f "%m" "$1" 2>/dev/null || echo 0
  else
    stat -c "%Y" "$1" 2>/dev/null || echo 0
  fi
}

to_epoch() {  # accept a bare epoch or an ISO8601 stamp; empty on failure
  case "$1" in
    ''|*[!0-9]*) : ;;
    *) printf '%s' "$1"; return 0 ;;
  esac
  date -u -d "$1" +%s 2>/dev/null && return 0          # GNU
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null && return 0   # BSD
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) RESET=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --since)
      shift
      [ $# -gt 0 ] || { echo "FAIL: --since needs a value (epoch or ISO8601)." >&2; exit 64; }
      SINCE="$(to_epoch "$1")" || {
        echo "FAIL: --since value '$1' is not an epoch or an ISO8601 stamp." >&2; exit 64; }
      shift ;;
    -h|--help) sed -n '2,97p' "$0"; exit 0 ;;
    -*) echo "unknown arg: $1" >&2; exit 64 ;;
    *) TARGETS="${TARGETS}${TARGETS:+|}$1"; shift ;;
  esac
done

if [ -z "$TARGETS" ]; then
  echo "FAIL: pass at least one deliverable path." >&2
  echo "usage: $0 <path> [<path>...] [--reset]" >&2
  exit 64
fi

say() { [ "$QUIET" -eq 1 ] || echo "$@"; }

mkdir -p "$STATE_DIR" 2>/dev/null || true
COUNTER_DIR="${STATE_DIR}/.wait-beats"
mkdir -p "$COUNTER_DIR" 2>/dev/null || true

key_of() { printf '%s' "$1" | cksum | tr -d ' \t' | cut -c1-16; }

# ---------------------------------------------------------------------------
# THE JOIN EPOCH. Recorded per target in a `.since` sidecar beside the counter, on
# the first beat, and reused by every later beat of the same join. The counter file
# itself stays a bare integer: consumers have live counters mid-sprint and nothing
# may change how those parse.
#
# --since is a HINT, not the authority. It is clamped so it can only pull the
# threshold EARLIER -- never past `now`, and never later than a value an earlier
# beat already settled on. Earlier is the direction only the caller can know
# (a teammate that delivered before this join armed, which is the normal shape
# after a compaction). Later is the direction that produces a threshold no write
# can ever satisfy.
# ---------------------------------------------------------------------------
join_of() {
  t_="$1"
  f_="${COUNTER_DIR}/$(key_of "$t_").since"
  now_="$(date +%s)"
  stored_=""
  [ -f "$f_" ] && stored_="$(cat "$f_" 2>/dev/null || echo '')"
  case "$stored_" in ''|*[!0-9]*) stored_="" ;; esac

  if [ -z "$stored_" ]; then j_="$now_"; else j_="$stored_"; fi
  [ -n "$SINCE" ] && [ "$SINCE" -lt "$j_" ] && j_="$SINCE"
  [ "$j_" -gt "$now_" ] && j_="$now_"

  printf '%s' "$j_" > "$f_" 2>/dev/null || true
  printf '%s' "$j_"
}

# The delivery predicate, single-sourced. Every place that asks "is this one done?"
# MUST come through here. If the pre-sweep and the poll loop disagree, the loop
# breaks the moment it sees a stale file present, the sweep then reports WAITING,
# and the beat returns in zero seconds having CHARGED a beat and slept none --
# ten instant beats straight to a false non-delivery.
is_delivered() {  # $1 = path, $2 = join epoch
  [ -s "$1" ] || return 1
  [ "$(mtime_of "$1")" -ge "$2" ]
}

# ---------------------------------------------------------------------------
# CHAINED-BEAT GUARD. Two invocations chained in one Bash call (`wait a; wait b`)
# share a parent shell, so they share $PPID. The first consumes the call's whole
# budget; the second then pushes the Bash call past it -- the exact Check A
# starvation this script exists to prevent, committed by the caller instead of
# the loop. If a sibling beat ran in this same shell moments ago, we do a single
# instantaneous check and return: we never sleep twice inside one Bash call.
# ---------------------------------------------------------------------------
# Prune stale shell markers before trusting one. They are keyed by PID, and PIDs
# recycle -- a marker left by a long-dead shell whose PID is reissued to ours
# would suppress a legitimate beat. Anything older than the budget cannot be a
# sibling of THIS call by definition, so it is safe to drop, and this also stops
# the markers accumulating forever.
find "$COUNTER_DIR" -maxdepth 1 -name '.shell-*' -mmin +"$(( (BUDGET / 60) + 1 ))" -delete 2>/dev/null || true

SIBLING="${COUNTER_DIR}/.shell-${PPID}"
MAY_SLEEP=1
if [ -f "$SIBLING" ]; then
  LAST="$(cat "$SIBLING" 2>/dev/null || echo 0)"
  case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
  if [ $(( $(date +%s) - LAST )) -lt "$BUDGET" ]; then
    MAY_SLEEP=0
  fi
fi
printf '%s' "$(date +%s)" > "$SIBLING" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Reset / already-delivered sweep, and the sequence bound. Done for every path
# BEFORE any sleeping: an exhausted sequence must not buy one more blind window.
# ---------------------------------------------------------------------------
PENDING=""
EXHAUSTED=""
PREEXISTING=""
OLDIFS="$IFS"; IFS='|'
for t in $TARGETS; do
  # A blank target is a malformed wait -- an empty In-Flight Teammates row cell,
  # or a lead that built the path from an unset variable. The old code silently
  # `continue`d past it, so a wave of nothing-but-blank paths fell straight
  # through to the `[ -z "$PENDING" ] && exit 0` below and reported DELIVERED: a
  # false join on a teammate that never ran. Fail loud and immediately instead.
  case "$t" in
    *[![:space:]]*) : ;;   # contains a non-whitespace char -- a real path
    *) echo "FAIL: empty/blank deliverable path in target list." >&2; exit 64 ;;
  esac
  c="${COUNTER_DIR}/$(key_of "$t")"
  s="${c}.since"
  [ "$RESET" -eq 1 ] && rm -f "$c" "$s" 2>/dev/null

  # Whether THIS beat armed the join must be read before join_of, which creates
  # the sidecar as a side effect.
  FIRST=0; [ -f "$s" ] || FIRST=1
  j="$(join_of "$t")"

  if is_delivered "$t" "$j"; then
    rm -f "$c" "$s" 2>/dev/null || true
    say "DELIVERED $t"
    continue
  fi

  # Non-empty, but not newer than the arming instant: the ambiguous case. Name it
  # on the one beat that decides it, so the lead learns the flag while it is still
  # actionable -- not at minute twenty via a non-delivery it cannot explain.
  [ "$FIRST" -eq 1 ] && [ -s "$t" ] && PREEXISTING="${PREEXISTING}${PREEXISTING:+|}$t"

  b=0; [ -f "$c" ] && b="$(cat "$c" 2>/dev/null || echo 0)"
  case "$b" in ''|*[!0-9]*) b=0 ;; esac

  if [ "$b" -ge "$MAX_BEATS" ]; then
    EXHAUSTED="${EXHAUSTED}${EXHAUSTED:+|}$t"
    continue
  fi

  # The counter is bumped ONLY if this invocation actually sleeps -- see below.
  # The sequence bound caps WAITING TIME (max_wait_beats x steering_budget); a
  # beat that did not wait is not a beat, and charging one for it burns the
  # budget without buying any wait. That is not academic: the reference consumer
  # wrapped beats in `for i in 3 4 5; do wait-for-deliverable.sh ...; done`, so
  # two of every three invocations were non-sleeping siblings -- and each still
  # took a beat. The counter hit the bound while the teammate was alive, the
  # script declared NON-DELIVERY, and Rule 20 tells the lead to re-dispatch on
  # that. The deliverable landed 4 minutes later. A false NON-DELIVERY re-
  # dispatches a live teammate, which is the exact failure this whole mechanism
  # exists to prevent.
  PENDING="${PENDING}${PENDING:+|}$t"
done
IFS="$OLDIFS"

if [ -n "$EXHAUSTED" ]; then
  IFS='|'; for t in $EXHAUSTED; do
    echo "NON-DELIVERY $t -- absent after $MAX_BEATS beats."
  done; IFS="$OLDIFS"
  echo "  Rule 20 defines an absent deliverable as non-delivery. Re-dispatch the"
  echo "  teammate ONCE (then re-run with --reset), and if it fails again, HARD_BLOCK."
  echo "  Do NOT keep beating: the wait never runs forever (Rule 29, Check C)."
  exit 1
fi

if [ -n "$PREEXISTING" ]; then
  NOW_="$(date +%s)"
  IFS='|'; for t in $PREEXISTING; do
    AGE_=$(( NOW_ - $(mtime_of "$t") ))
    if   [ "$AGE_" -ge 86400 ]; then AGE_H="$(( AGE_ / 86400 ))d old"
    elif [ "$AGE_" -ge 3600 ];  then AGE_H="$(( AGE_ / 3600 ))h old"
    else                             AGE_H="$(( AGE_ / 60 ))m old"
    fi
    echo "NOTE      $t already had content when this join armed (${AGE_H})."
  done; IFS="$OLDIFS"
  echo "  Not accepting it on sight; this join waits for a write NEWER than the"
  echo "  arming instant. A file that predates the join cannot be shown to be THIS"
  echo "  dispatch's answer -- it is equally the previous sprint's artifact at a"
  echo "  reused path, and consuming that is a silent wrong answer."
  echo "  If your teammate may have delivered BEFORE this join armed (the normal"
  echo "  shape when you are resuming a join after a compaction), re-run with the"
  echo "  dispatch time from the snapshot's In-Flight Teammates row:"
  echo "    scripts/ai-dlc/wait-for-deliverable.sh --since <epoch|ISO8601> <path> ..."
fi

[ -z "$PENDING" ] && exit 0   # everything was already delivered

if [ "$MAY_SLEEP" -eq 0 ]; then
  IFS='|'; for t in $PENDING; do echo "WAITING   $t -- not yet delivered."; done; IFS="$OLDIFS"
  echo "  NOTE: a sibling beat already ran in this same Bash call, so this one did"
  echo "  NOT sleep and did NOT consume a beat -- two beats in one call would push"
  echo "  it past the ${BUDGET}s steering budget (Rule 29, Check A). Do not loop or chain"
  echo "  beats; pass every deliverable to ONE call, and beat again on the NEXT call:"
  echo "    scripts/ai-dlc/wait-for-deliverable.sh path-a path-b path-c"
  exit 0
fi

# This invocation is going to wait, so it costs a beat. Charge it here and
# nowhere else.
IFS='|'
for t in $PENDING; do
  c="${COUNTER_DIR}/$(key_of "$t")"
  b=0; [ -f "$c" ] && b="$(cat "$c" 2>/dev/null || echo 0)"
  case "$b" in ''|*[!0-9]*) b=0 ;; esac
  printf '%s' "$(( b + 1 ))" > "$c" 2>/dev/null || true
done
IFS="$OLDIFS"

# ---------------------------------------------------------------------------
# ONE beat, polling every pending path. The loop sleeps AFTER its check, so the
# worst-case beat runs to `deadline + POLL`; the reserve must cover a whole poll
# interval or a large POLL silently pushes the beat past the budget.
# ---------------------------------------------------------------------------
RESERVE="$MARGIN"
[ "$POLL" -gt "$RESERVE" ] && RESERVE="$POLL"
DEADLINE=$(( $(date +%s) + BUDGET - RESERVE ))

# ---------------------------------------------------------------------------
# Beat-liveness marker (v0.81.0). A live, backgrounded beat is the ONLY state in
# which the lead may end its turn: the Stop hook (ai-dlc-continue.sh Check 2b)
# allows the yield iff this marker exists and is unexpired, because THIS process
# will exit and re-invoke the idle lead. We write it only here, on the genuine-
# sleep path (a non-sleeping return above never reaches this line), so a
# foreground beat clears it on exit via the trap and post-beat prose still
# BLOCKS -- unchanged behavior. The stored epoch is the true worst-case beat
# end (`DEADLINE + POLL`, still <= now + BUDGET since RESERVE >= POLL): the hook's
# `epoch > now` test rejects a SIGKILLed beat's stale marker with no cleanup
# dependency, exactly like the `.shell-*` mmin prune above self-heals.
BEAT_MARKER="${STATE_DIR}/.beat-inflight"
printf '%s' "$(( DEADLINE + POLL ))" > "$BEAT_MARKER" 2>/dev/null || true
trap 'rm -f "$BEAT_MARKER" 2>/dev/null || true' EXIT

all_present() {
  IFS='|'
  for t in $PENDING; do
    if ! is_delivered "$t" "$(join_of "$t")"; then IFS="$OLDIFS"; return 1; fi
  done
  IFS="$OLDIFS"; return 0
}

while :; do
  if all_present; then break; fi
  [ "$(date +%s)" -ge "$DEADLINE" ] && break
  sleep "$POLL"
done

RC=0
N_DELIVERED=0
N_WAITING=0
IFS='|'
for t in $PENDING; do
  c="${COUNTER_DIR}/$(key_of "$t")"
  s="${c}.since"
  if is_delivered "$t" "$(join_of "$t")"; then
    rm -f "$c" "$s" 2>/dev/null || true
    say "DELIVERED $t"
    N_DELIVERED=$(( N_DELIVERED + 1 ))
  else
    b="$(cat "$c" 2>/dev/null || echo '?')"
    say "WAITING   $t -- beat $b/$MAX_BEATS, not yet delivered. Beat again."
    N_WAITING=$(( N_WAITING + 1 ))
  fi
done
IFS="$OLDIFS"

# The beat ran to completion, which is what exit 0 now means -- NOT "everything
# landed". A wave beat can finish with some paths delivered and some still out, so
# the last line states which, and the lead consumes only the DELIVERED ones. This
# is the line that has to be unmissable: the exit code no longer carries it.
if [ "$N_WAITING" -eq 0 ]; then
  say "BEAT COMPLETE -- all ${N_DELIVERED} delivered. Consume them."
else
  say "BEAT COMPLETE -- ${N_DELIVERED} delivered, ${N_WAITING} still out. Consume only the DELIVERED paths, then beat again."
fi

exit "$RC"
