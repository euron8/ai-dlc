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
# So: one call site, ~25 tokens, and the two bounds are enforced HERE rather
# than trusted to the caller.
#
#   THE CALL BOUND  -- this script never runs longer than the steering budget.
#                      Every invocation is ONE beat and returns inside it, so a
#                      queued operator message lands at the next tool boundary.
#   THE SEQUENCE BOUND -- beats are COUNTED across calls in a sidecar. At
#                      max_wait_beats the script stops returning "beat again"
#                      and declares Rule 20 non-delivery. An unbounded wait is a
#                      hang, not a gag (Rule 29), and this is what makes the
#                      sequence terminate without the lead having to remember.
#
# USAGE
#   scripts/wait-for-deliverable.sh <deliverable-path> [--reset] [--quiet]
#
# EXIT CODES (distinct on purpose -- the lead branches on these)
#   0  DELIVERED     the file exists and is non-empty. Consume it. Counter cleared.
#   2  WAITING       not yet delivered, beats remain. Call again (this is a beat).
#   1  NON-DELIVERY  max_wait_beats exhausted. Rule 20 non-delivery: re-dispatch
#                    ONCE (with --reset), then HARD_BLOCK. Never beat past this.
#
# ENV
#   AI_DLC_STEERING_BUDGET   seconds a beat may take        (default 120)
#   AI_DLC_WAIT_POLL_SECS    seconds between polls          (default 10)
#   AI_DLC_MAX_WAIT_BEATS    beats before non-delivery      (default 10)
#   AI_DLC_STATE_DIR         state dir                      (default _bmad-output)

set -u

BUDGET="${AI_DLC_STEERING_BUDGET:-120}"
POLL="${AI_DLC_WAIT_POLL_SECS:-10}"
MAX_BEATS="${AI_DLC_MAX_WAIT_BEATS:-10}"
STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"

# Margin keeps the beat strictly INSIDE the budget. A beat that lands exactly on
# the budget is a beat that can overshoot it under load, and an over-budget call
# is precisely the window in which the operator cannot be heard (Check A).
MARGIN="${AI_DLC_WAIT_MARGIN_SECS:-10}"

QUIET=0
RESET=0
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) RESET=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
    -*) echo "unknown arg: $1" >&2; exit 64 ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "FAIL: pass the deliverable path. usage: $0 <deliverable-path> [--reset]" >&2
  exit 64
fi

say() { [ "$QUIET" -eq 1 ] || echo "$@"; }

# ---------------------------------------------------------------------------
# Beat counter. Keyed by the deliverable path, so two teammates waited on
# concurrently keep separate counts.
# ---------------------------------------------------------------------------
mkdir -p "$STATE_DIR" 2>/dev/null || true
COUNTER_DIR="${STATE_DIR}/.wait-beats"
mkdir -p "$COUNTER_DIR" 2>/dev/null || true

# A path is not a filename; hash it. `cksum` is POSIX and everywhere, and a
# collision here would only merge two counters, never lose a deliverable.
KEY="$(printf '%s' "$TARGET" | cksum | tr -d ' \t' | cut -c1-16)"
COUNTER="${COUNTER_DIR}/${KEY}"

if [ "$RESET" -eq 1 ]; then
  rm -f "$COUNTER" 2>/dev/null || true
  say "RESET     beat counter cleared for $TARGET"
fi

BEAT=0
[ -f "$COUNTER" ] && BEAT="$(cat "$COUNTER" 2>/dev/null || echo 0)"
case "$BEAT" in ''|*[!0-9]*) BEAT=0 ;; esac

# ---------------------------------------------------------------------------
# Delivered already? Answer before spending a beat.
# ---------------------------------------------------------------------------
if [ -s "$TARGET" ]; then
  rm -f "$COUNTER" 2>/dev/null || true
  say "DELIVERED $TARGET"
  exit 0
fi

# ---------------------------------------------------------------------------
# Sequence bound. Check BEFORE polling: an exhausted sequence must not buy one
# more blind window.
# ---------------------------------------------------------------------------
if [ "$BEAT" -ge "$MAX_BEATS" ]; then
  echo "NON-DELIVERY $TARGET -- absent after $BEAT beats (~$(( BEAT * BUDGET / 60 )) min)."
  echo "  Rule 20 defines an absent deliverable as non-delivery. Re-dispatch the"
  echo "  teammate ONCE (then re-run with --reset), and if it fails again, HARD_BLOCK."
  echo "  Do NOT keep beating: the wait never runs forever (Rule 29, Check C)."
  exit 1
fi

BEAT=$(( BEAT + 1 ))
printf '%s' "$BEAT" > "$COUNTER" 2>/dev/null || true

# ---------------------------------------------------------------------------
# ONE beat. Poll inside the call, but never outlast the budget.
#
# The loop sleeps AFTER its check, so the worst-case beat runs to
# `deadline + POLL`. The reserve must therefore cover a whole poll interval, or
# a large AI_DLC_WAIT_POLL_SECS silently pushes the beat past the budget -- an
# over-budget call being the one thing this script exists to make impossible.
# ---------------------------------------------------------------------------
RESERVE="$MARGIN"
[ "$POLL" -gt "$RESERVE" ] && RESERVE="$POLL"
DEADLINE=$(( $(date +%s) + BUDGET - RESERVE ))
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  if [ -s "$TARGET" ]; then
    rm -f "$COUNTER" 2>/dev/null || true
    say "DELIVERED $TARGET (beat $BEAT/$MAX_BEATS)"
    exit 0
  fi
  sleep "$POLL"
done

# Last look: the file may have landed during the final sleep.
if [ -s "$TARGET" ]; then
  rm -f "$COUNTER" 2>/dev/null || true
  say "DELIVERED $TARGET (beat $BEAT/$MAX_BEATS)"
  exit 0
fi

say "WAITING   $TARGET -- beat $BEAT/$MAX_BEATS, not yet delivered. Beat again."
exit 2
