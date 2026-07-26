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
#   THE CALL BOUND  -- this script never runs longer than the BEAT QUANTUM
#                      (AI_DLC_WAIT_BEAT_SECS). Every invocation is ONE beat and
#                      returns inside it, so the lead is re-invoked and can act
#                      on whatever landed.
#   THE SEQUENCE BOUND -- beats are COUNTED across calls in a sidecar. At
#                      max_wait_beats the script declares Rule 20 non-delivery.
#                      An unbounded wait is a hang, not a gag (Rule 29).
#
# THE BEAT QUANTUM IS NOT THE STEERING BUDGET. Both were once
# AI_DLC_STEERING_BUDGET, and the shared name was the bug. The steering budget
# bounds a FOREGROUND call, because the operator cannot be heard while one is in
# flight. This beat is BACKGROUNDED (v0.81.0): the lead has ended its turn, so a
# queued operator message lands on the very next turn no matter how long the beat
# sleeps. The quantum therefore buys nothing for steerability -- it only decides
# how often a still-waiting join re-invokes the lead, and every one of those
# re-invocations costs a turn. validate-steering-budget.sh already agrees: Check A
# skips run_in_background calls and isWaitBeat requires foreground, so the
# validator never bound this script to 120s in the first place.
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
# NON-DELIVERY MEANS "NO EVIDENCE OF WORK", NOT "TIME ELAPSED". The sequence bound
# below is a clock, and a clock cannot tell a slow teammate from a dead one. So the
# mechanism built to stop a lead re-dispatching a live teammate periodically causes
# exactly that. Three recurrences, and the first two fixes both only moved the
# threshold:
#
#   1. S297 -- `adversary-p1-rr` declared non-delivered at the then-20-minute
#      ceiling; a LIVE teammate was re-dispatched. Fix: ceiling 20 -> 60 minutes.
#   2. Non-sleeping siblings charged a beat without waiting, so the counter reached
#      the bound while the teammate was alive and the deliverable landed four
#      minutes later. Fix: charge a beat only when the invocation sleeps (below).
#   3. S298 -- a legitimate 62-minute dispatch, which exceeds even the raised
#      ceiling, and a second dispatch on the same trajectory. The lead pre-empted
#      the false NON-DELIVERY BY HAND, checking `git status` in the teammate's
#      worktree for changed files and re-arming instead of re-dispatching. That
#      the lead had to hand-write the liveness check is the defect.
#
# --progress-path is that hand-written check, mechanized. Point it at where the
# teammate WORKS (its worktree), and each beat asks whether any file under it was
# written since the previous beat. If so the teammate is demonstrably working, and
# an exhausted sequence is EXTENDED by one beat instead of declaring non-delivery.
# Omit the flag and behaviour is byte-for-byte what it was: strictly additive.
#
# THE EXTENSION IS BOUNDED, AND THAT IS NOT OPTIONAL. Rule 29's Check C is the
# other half of this script's contract -- an unbounded wait is a hang, not a gag --
# so "progress resets the counter" would trade a false NON-DELIVERY for a join that
# can never terminate. A teammate stuck in a loop touching a log file every ten
# minutes would hold the lead forever, and the Rule 26(c) claim that this script
# "can commit neither" failure would quietly become false. So grants are counted
# too, in their own sidecar, capped at max_wait_beats. Worst case doubles; it does
# not become infinite.
#
# WHY NOT A PROGRESS PATH THE SCRIPT PICKS ITSELF. Only the caller knows which tree
# the teammate was pointed at, and a guessed one is worse than none: a path nothing
# writes to makes the grant unreachable and the feature inert, which reads exactly
# like a feature that is working. Hence an explicit flag, and hence the hard errors
# on a path that does not exist and on the state dir (see the guards below) -- both
# are ways this check could silently never fire.
#
# USAGE
#   scripts/ai-dlc/wait-for-deliverable.sh <path> [<path>...] [--reset] [--quiet]
#                                   [--since <epoch|ISO8601>]
#                                   [--progress-path <dir|file>]...
#
# EXIT CODES
#   0  BEAT COMPLETE  the beat ran and returned. Read stdout for per-path status:
#                     `DELIVERED <path>` / `WAITING <path>`, then the BEAT COMPLETE
#                     summary line. Consume ONLY the delivered paths.
#                     `PROGRESS <path>` means an exhausted sequence was extended
#                     because work was observed -- do NOT re-dispatch, beat again.
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
#   AI_DLC_WAIT_BEAT_SECS    seconds a beat may sleep       (default 600)
#   AI_DLC_WAIT_POLL_SECS    seconds between polls          (default 10)
#   AI_DLC_MAX_WAIT_BEATS    beats before non-delivery      (default 6, and it is
#                            also the cap on progress grants, so the worst-case
#                            wait is 2 x quantum x this -- still finite)
#   AI_DLC_WAIT_MARGIN_SECS  reserve held back from quantum (default 10)
#   AI_DLC_STATE_DIR         state dir                      (default _bmad-output)
#
# AI_DLC_STEERING_BUDGET is deliberately NOT read here -- see "THE BEAT QUANTUM
# IS NOT THE STEERING BUDGET" above. It bounds foreground calls and belongs to
# validate-steering-budget.sh alone.
#
# The wall-clock ceiling is quantum x max_wait_beats = 60 minutes, or twice that
# when --progress-path is supplied and every grant is spent. The previous 20
# minutes was too short for what teammates actually take: S297 declared
# `adversary-p1-rr` non-delivered at the ceiling and re-dispatched a live
# teammate, and S298 ran a legitimate 62-minute dispatch -- which exceeds the
# raised ceiling too, and is why raising it again is not the fix.

set -u

BUDGET="${AI_DLC_WAIT_BEAT_SECS:-600}"
POLL="${AI_DLC_WAIT_POLL_SECS:-10}"
MAX_BEATS="${AI_DLC_MAX_WAIT_BEATS:-6}"
STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"
MARGIN="${AI_DLC_WAIT_MARGIN_SECS:-10}"

QUIET=0
RESET=0
TARGETS=""
SINCE=""
PROGRESS_PATHS=""

# ---------------------------------------------------------------------------
# Platform probes, done ONCE. `stat` and `date` split BSD/GNU on exactly the two
# things this script needs, and probing per poll would re-fork them every 10s for
# the life of a 60-minute join.
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
    --progress-path)
      shift
      [ $# -gt 0 ] || { echo "FAIL: --progress-path needs a path." >&2; exit 64; }
      # A path that does not exist yields no hits forever, so the grant becomes
      # unreachable and this whole check silently never fires. Refuse it here --
      # a typo must not read as "the teammate is not working".
      [ -e "$1" ] || {
        echo "FAIL: --progress-path '$1' does not exist. A missing progress path" >&2
        echo "  can never show evidence of work, so the check would silently never" >&2
        echo "  fire. Pass the directory the teammate actually writes in." >&2
        exit 64; }
      PROGRESS_PATHS="${PROGRESS_PATHS}${PROGRESS_PATHS:+|}$1"
      shift ;;
    -h|--help) sed -n '2,164p' "$0"; exit 0 ;;
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

abs_of() {  # normalized absolute path; no realpath dependency (not on BSD by default)
  if [ -d "$1" ]; then ( cd "$1" 2>/dev/null && pwd -P ); return; fi
  d_="$(dirname "$1")"; b_="$(basename "$1")"
  ( cd "$d_" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$b_" )
}

mkdir -p "$STATE_DIR" 2>/dev/null || true
COUNTER_DIR="${STATE_DIR}/.wait-beats"
mkdir -p "$COUNTER_DIR" 2>/dev/null || true

# ---------------------------------------------------------------------------
# THE PROGRESS PATH MAY NOT BE THE STATE DIR, OR ANY ANCESTOR OF IT.
# `_bmad-output` is the obvious thing to reach for -- it is where deliverables
# live -- and it is the one path that makes this check unable to fail. THIS beat
# re-stamps `.beat-inflight` every poll and writes its own counters there, and the
# lead rewrites the snapshot and the continuation log every turn. Evidence of work
# would then be permanently true, NON-DELIVERY could never fire, and the join
# would be exactly the unbounded wait Rule 29 Check C forbids -- while printing a
# reassuring PROGRESS line each beat. Fail loudly instead, and name the fix.
# ---------------------------------------------------------------------------
if [ -n "$PROGRESS_PATHS" ]; then
  SD_ABS="$(abs_of "$STATE_DIR")"
  OLDIFS="$IFS"; IFS='|'
  for p in $PROGRESS_PATHS; do
    IFS="$OLDIFS"
    P_ABS="$(abs_of "$p")"
    if [ -n "$P_ABS" ] && [ -n "$SD_ABS" ] && \
       { [ "$P_ABS" = "$SD_ABS" ] || case "$SD_ABS" in "$P_ABS"/*) true ;; *) false ;; esac; }; then
      echo "FAIL: --progress-path '$p' is the state dir ('$STATE_DIR') or contains it." >&2
      echo "  This beat writes its own counters and .beat-inflight there, and the lead" >&2
      echo "  rewrites the snapshot every turn, so progress would ALWAYS be observed and" >&2
      echo "  NON-DELIVERY could never fire -- an unbounded wait (Rule 29, Check C)." >&2
      echo "  Point it at where the TEAMMATE works, e.g. its worktree:" >&2
      echo "    --progress-path .claude/worktrees/<teammate>" >&2
      exit 64
    fi
    IFS='|'
  done
  IFS="$OLDIFS"
fi

# ---------------------------------------------------------------------------
# COUNTERS ARE SCOPED TO THE BOUND THEY WERE COUNTED AGAINST.
# The counters survive a pull, and a live join carrying a count of 7 against an
# old bound of 10 would exhaust on its FIRST beat under a new bound of 6 -- a
# false NON-DELIVERY that re-dispatches a live teammate, which is the exact
# failure this whole script exists to prevent. So record the active bound and
# wipe the counters once whenever it changes. Self-heals for this retune and any
# future one; the `.since` sidecars go with them, which is correct, because a
# re-armed join must re-capture its epoch anyway.
BOUND_FILE="${COUNTER_DIR}/.bound"
PREV_BOUND="$(cat "$BOUND_FILE" 2>/dev/null || echo '')"
if [ "$PREV_BOUND" != "$MAX_BEATS" ]; then
  rm -rf "$COUNTER_DIR" 2>/dev/null || true
  mkdir -p "$COUNTER_DIR" 2>/dev/null || true
  printf '%s' "$MAX_BEATS" > "$BOUND_FILE" 2>/dev/null || true
fi

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
# EVIDENCE OF WORK, as a delta and not a state. The lead's hand-written version of
# this check was `git status` in the teammate's worktree -- but "there are changed
# files" stays true forever after the first edit, including long after the teammate
# died mid-edit. What it actually recorded, and what makes it a liveness signal, was
# the CHANGE between two observations. So: a mark file per join, re-stamped once per
# sleeping beat, and the question is whether anything is newer than the mark.
#
# `-newer` and `-prune` are POSIX. `-newermt` is GNU-only and `-quit` is not on
# every BSD find, so neither appears here. Nor does a pipe to `head`: the output is
# captured whole, because a pipe that closes early turns SIGPIPE into "not found"
# and reports a present thing absent. Only files written inside the last beat can
# match, so the capture is a handful of lines however large the tree is; the
# traversal is the cost, once per quantum.
#
# The prune is not defensive decoration. A teammate worktree carries its own
# `_bmad-output/`, so a teammate that runs its own beats leaves `.wait-beats/` and
# `.beat-inflight` ticking inside the very tree we are watching -- machinery
# heartbeats, not work. The state-dir guard above cannot see those: they are not
# THIS run's state dir.
# ---------------------------------------------------------------------------
progressed_since() {  # $1 = mark file; 0 iff a tracked file is newer than it
  [ -n "$PROGRESS_PATHS" ] || return 1
  [ -f "$1" ] || return 1
  ps_ifs_="$IFS"; hit_=""
  IFS='|'
  for p_ in $PROGRESS_PATHS; do
    IFS="$ps_ifs_"
    hit_="$(find "$p_" \( -name .git -o -name .wait-beats \) -prune \
                 -o -type f ! -name '.beat-inflight' -newer "$1" -print 2>/dev/null)"
    if [ -n "$hit_" ]; then IFS="$ps_ifs_"; return 0; fi
    IFS='|'
  done
  IFS="$ps_ifs_"
  return 1
}

# ---------------------------------------------------------------------------
# CHAINED-BEAT GUARD. Two invocations chained in one Bash call (`wait a; wait b`)
# share a parent shell, so they share $PPID. The first consumes the call's whole
# quantum; the second then serializes a second one behind it, so the wave waits
# 2x as long as it needed to for no gain -- the wave should have gone to ONE call
# and polled concurrently. If a sibling beat ran in this same shell moments ago,
# we do a single instantaneous check and return: we never sleep twice inside one
# Bash call.
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
GRANTED=""
GRANTSPENT=""
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
  pg="${c}.progress"
  gr="${c}.grants"
  [ "$RESET" -eq 1 ] && rm -f "$c" "$s" "$pg" "$gr" 2>/dev/null

  # Whether THIS beat armed the join must be read before join_of, which creates
  # the sidecar as a side effect.
  FIRST=0; [ -f "$s" ] || FIRST=1
  j="$(join_of "$t")"

  if is_delivered "$t" "$j"; then
    rm -f "$c" "$s" "$pg" "$gr" 2>/dev/null || true
    say "DELIVERED $t"
    continue
  fi

  # Non-empty, but not newer than the arming instant: the ambiguous case. Name it
  # on the one beat that decides it, so the lead learns the flag while it is still
  # actionable -- not at minute twenty via a non-delivery it cannot explain.
  [ "$FIRST" -eq 1 ] && [ -s "$t" ] && PREEXISTING="${PREEXISTING}${PREEXISTING:+|}$t"

  b=0; [ -f "$c" ] && b="$(cat "$c" 2>/dev/null || echo 0)"
  case "$b" in ''|*[!0-9]*) b=0 ;; esac

  # Sample evidence of work, then re-stamp the mark, so the next beat asks about
  # the window that is about to start. Gated on MAY_SLEEP for the same reason the
  # counter is: a non-sleeping sibling that re-stamped the mark would shrink the
  # observation window to nothing and report a working teammate as idle.
  PROGRESSED=0
  if [ -n "$PROGRESS_PATHS" ] && [ "$MAY_SLEEP" -eq 1 ]; then
    progressed_since "$pg" && PROGRESSED=1
    : > "$pg" 2>/dev/null || true
  fi

  if [ "$b" -ge "$MAX_BEATS" ]; then
    # The sequence is spent. Before calling it non-delivery -- which Rule 20 turns
    # into a re-dispatch -- ask whether the teammate is demonstrably working. A
    # grant buys exactly ONE more beat and is itself counted, so this can extend
    # the wait but can never remove its end.
    g=0; [ -f "$gr" ] && g="$(cat "$gr" 2>/dev/null || echo 0)"
    case "$g" in ''|*[!0-9]*) g=0 ;; esac

    if [ "$PROGRESSED" -eq 1 ] && [ "$g" -lt "$MAX_BEATS" ]; then
      g=$(( g + 1 ))
      printf '%s' "$g" > "$gr" 2>/dev/null || true
      printf '%s' "$(( MAX_BEATS - 1 ))" > "$c" 2>/dev/null || true
      GRANTED="${GRANTED}${GRANTED:+|}${g}/${MAX_BEATS} $t"
      PENDING="${PENDING}${PENDING:+|}$t"
      continue
    fi

    [ "$PROGRESSED" -eq 1 ] && GRANTSPENT="${GRANTSPENT}${GRANTSPENT:+|}$t"
    EXHAUSTED="${EXHAUSTED}${EXHAUSTED:+|}$t"
    continue
  fi

  # The counter is bumped ONLY if this invocation actually sleeps -- see below.
  # The sequence bound caps WAITING TIME (max_wait_beats x the beat quantum); a
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

# Printed with echo, not `say`: this is the line that tells the lead NOT to act on
# an exhausted sequence, and --quiet must not be able to hide it.
if [ -n "$GRANTED" ]; then
  IFS='|'; for e in $GRANTED; do
    echo "PROGRESS  ${e#* } -- work observed under the progress path; sequence"
    echo "  extended by one beat (grant ${e%% *}). The teammate is demonstrably"
    echo "  working, so this is NOT Rule 20 non-delivery. Do NOT re-dispatch; beat again."
  done; IFS="$OLDIFS"
fi

if [ -n "$EXHAUSTED" ]; then
  IFS='|'; for t in $EXHAUSTED; do
    echo "NON-DELIVERY $t -- absent after $MAX_BEATS beats."
  done; IFS="$OLDIFS"
  if [ -n "$GRANTSPENT" ]; then
    IFS='|'; for t in $GRANTSPENT; do
      echo "  NOTE: $t still shows work under the progress path, but all $MAX_BEATS"
      echo "  progress grants are spent. The bound is deliberate -- a teammate that"
      echo "  keeps writing without delivering is a hang, and Rule 29 Check C says a"
      echo "  wait must end. Decide: re-dispatch, or --reset if you have read the"
      echo "  worktree and judged it genuinely close."
    done; IFS="$OLDIFS"
  fi
  echo "  Rule 20 defines an absent deliverable as non-delivery. Re-dispatch the"
  echo "  teammate ONCE (then re-run with --reset), and if it fails again, HARD_BLOCK."
  echo "  Do NOT keep beating: the wait never runs forever (Rule 29, Check C)."
  if [ -z "$PROGRESS_PATHS" ]; then
    echo "  Before you re-dispatch: an exhausted clock is not evidence of death. If the"
    echo "  teammate may still be working, re-arm with --reset --progress-path <its"
    echo "  worktree> and this beat will extend the sequence while it keeps writing."
  fi
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
  echo "  NOT sleep and did NOT consume a beat -- two beats in one call serialize"
  echo "  into 2 x ${BUDGET}s for a wave that ONE call polls concurrently. Do not loop"
  echo "  or chain beats; pass every deliverable to ONE call, and beat again next call:"
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
# BLOCKS -- unchanged behavior.
#
# IT IS A HEARTBEAT, NOT A PROMISE. The marker once held the beat's worst-case
# END epoch, written once. A SIGKILLed beat skips the EXIT trap, so the lead was
# then free to keep yielding until that epoch with NOTHING scheduled to re-invoke
# it -- and the size of that dead window was exactly the beat quantum. At 120s
# that was tolerable; at 600s it would not be. So the loop re-stamps the marker
# every poll with `now + 2*POLL`: a live beat keeps it ~20s ahead, and a dead
# one's marker goes stale within ~20s no matter how large the quantum is. The
# hook's `epoch > now` test is unchanged, and so is the fail-safe direction --
# a stale marker falls through to the Rule 3 block, which force-continues.
#
# 3*POLL, not 1*POLL: the hook may read the marker at any point between two
# re-stamps, so the lease must outlast a whole poll interval plus slack for a
# loaded machine. Too SHORT costs a spurious Rule 3 block on a healthy join;
# too LONG costs idle time after a kill. 30s of lease for 10s of polling puts
# the slack where the cheaper mistake is.
BEAT_MARKER="${STATE_DIR}/.beat-inflight"
beat_alive() { printf '%s' "$(( $(date +%s) + 3 * POLL ))" > "$BEAT_MARKER" 2>/dev/null || true; }
beat_alive
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
  beat_alive
done

RC=0
N_DELIVERED=0
N_WAITING=0
IFS='|'
for t in $PENDING; do
  c="${COUNTER_DIR}/$(key_of "$t")"
  s="${c}.since"
  if is_delivered "$t" "$(join_of "$t")"; then
    rm -f "$c" "$s" "${c}.progress" "${c}.grants" 2>/dev/null || true
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
