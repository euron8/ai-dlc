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
#     scripts/wait-for-deliverable.sh docs/reviews/a.md docs/reviews/b.md ...
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
# USAGE
#   scripts/wait-for-deliverable.sh <path> [<path>...] [--reset] [--quiet]
#
# EXIT CODES (distinct on purpose -- the lead branches on these)
#   0  DELIVERED     every path exists and is non-empty. Consume them.
#   2  WAITING       at least one is absent, beats remain. Call again.
#   1  NON-DELIVERY  a path exhausted max_wait_beats. Rule 20 non-delivery:
#                    re-dispatch ONCE (with --reset), then HARD_BLOCK.
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
MARGIN="${AI_DLC_WAIT_MARGIN_SECS:-10}"

QUIET=0
RESET=0
TARGETS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) RESET=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,55p' "$0"; exit 0 ;;
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
  [ "$RESET" -eq 1 ] && rm -f "$c" 2>/dev/null

  if [ -s "$t" ]; then
    rm -f "$c" 2>/dev/null || true
    say "DELIVERED $t"
    continue
  fi

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

[ -z "$PENDING" ] && exit 0   # everything was already on disk

if [ "$MAY_SLEEP" -eq 0 ]; then
  IFS='|'; for t in $PENDING; do echo "WAITING   $t -- not yet delivered."; done; IFS="$OLDIFS"
  echo "  NOTE: a sibling beat already ran in this same Bash call, so this one did"
  echo "  NOT sleep and did NOT consume a beat -- two beats in one call would push"
  echo "  it past the ${BUDGET}s steering budget (Rule 29, Check A). Do not loop or chain"
  echo "  beats; pass every deliverable to ONE call, and beat again on the NEXT call:"
  echo "    scripts/wait-for-deliverable.sh path-a path-b path-c"
  exit 2
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
    if [ ! -s "$t" ]; then IFS="$OLDIFS"; return 1; fi
  done
  IFS="$OLDIFS"; return 0
}

while :; do
  if all_present; then break; fi
  [ "$(date +%s)" -ge "$DEADLINE" ] && break
  sleep "$POLL"
done

RC=0
IFS='|'
for t in $PENDING; do
  c="${COUNTER_DIR}/$(key_of "$t")"
  if [ -s "$t" ]; then
    rm -f "$c" 2>/dev/null || true
    say "DELIVERED $t"
  else
    b="$(cat "$c" 2>/dev/null || echo '?')"
    say "WAITING   $t -- beat $b/$MAX_BEATS, not yet delivered. Beat again."
    RC=2
  fi
done
IFS="$OLDIFS"

exit "$RC"
