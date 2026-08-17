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
broken=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# A short beat keeps the suite fast. AI_DLC_WAIT_MARGIN_SECS is load-bearing and
# easy to miss: MARGIN defaults to 10, and RESERVE = max(MARGIN, POLL), so with the
# default the deadline would land in the PAST, the poll loop would break on its
# first iteration, and every timing assertion below would pass or fail by luck.
# Output goes to a file rather than command substitution: `OUT="$(beat ...)"` would
# run the function in a subshell, so the RC it sets would never reach the caller and
# every exit-code assertion would read a stale value.
# ONE PROCESS PER CASE, AND THE REASON IS WALL CLOCK. This fixture is SLEEP-bound: nearly
# every case below waits out a beat quantum to prove the beat actually slept, and run end to
# end that is ~52s of a suite whose next-longest unit is a third of it. The cases are already
# independent -- seed.sh gives each its OWN tree, and its header says why (the counter and the
# join sidecar are keyed by the target path STRING, so two cases sharing a state dir would
# share state). They were independent and merely written in a row. Each is now a function run
# in its own process, and the driver at the foot of this file runs them through a pool.
#
# A SLEEPING CASE IS NOT A BUSY CASE, which is what makes this safe to nest inside the
# suite's own pool: these workers are waiting on a clock, not competing for a core.
# The wall-clock ASSERTIONS are the risk instead -- `ELAPSED -le 1` for "returned without
# sleeping", `-ge 6` for a quantum honoured -- so this cannot be proven by a differential
# alone. It needs repeated runs at the shipping pool size, and that evidence is the release.
setup_tmp() {
  BEATOUT="$(mktemp)"
  MUTDIR="$(mktemp -d 2>/dev/null || mktemp -d -t wait-mutants)"
  trap 'rm -f "$BEATOUT"; rm -rf "$MUTDIR"' EXIT
}
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
# A CHAINED SIBLING, BUILT WHERE THE MARKER CAN BE BUILT.
# `wait a; wait b` in one Bash call gives both invocations the same parent shell,
# so both see `.shell-$PPID` and the second runs with MAY_SLEEP=0. seed.sh cannot
# seed that marker: it is keyed on the PID of the shell that INVOKES the subject,
# and seed.sh is a different process. So the marker is written by the very shell
# that then runs the subject as a CHILD -- `$$` inside that `bash -c` is the
# subject's `$PPID`. `exec` would be wrong here for the same reason: an exec'd
# process inherits the GRANDPARENT as its parent, so the marker would name a PID
# the subject never looks up and every chained case would silently run with
# MAY_SLEEP=1 -- passing, against the wrong code path.
#
# Content, not just the name, comes from what the subject's own producer writes at
# `printf '%s' "$(date +%s)" > "$SIBLING"` -- an epoch, no newline. Seeding what
# the READER happens to tolerate would prove only that the reader accepts the
# fixture's grammar.
#
# THE TRAILING `exit $?` IS THE WHOLE MECHANISM, NOT TIDINESS. bash EXECS the last
# command of a `-c` string when it is a simple command, so `bash "$s"` REPLACES the
# wrapper shell and the subject's parent becomes the wrapper's own parent -- the
# marker then names a PID the subject never looks up. Measured on bash 3.2.57:
# without a trailing builtin the child reports PPID=86777 against a wrapper $$ of
# 86779; with `exit $?` appended the two are equal. The first form is how this
# helper was first written, and every chained case ran with MAY_SLEEP=1 -- which
# presented as a two-minute HANG rather than as a wrong verdict, because the subject
# went to sleep for its quantum. `sibling_witness` is the standing guard on it.
#
# THE QUANTUM IS 60 HERE, NOT 4, AND THAT IS THE DETERMINISM ARGUMENT. The subject
# calls a marker a sibling's iff `now - LAST < BUDGET`, so at BUDGET=4 this fixture
# would be asserting that a `date` fork, a file write and a `bash` startup all
# complete within four seconds -- true today, and a flake on a machine running this
# pool nested inside the suite's, landing as a false FAIL on an unrelated change. A
# chained beat never sleeps, so the larger quantum costs the passing path nothing.
# It is not 600 either: if MAY_SLEEP is ever 1 here the beat DOES sleep, and the
# quantum is then the wall clock this case adds before `sibling_witness` reports it.
# 60 buys slack no scheduling delay can cross while keeping that regression a slow
# FAIL rather than a ten-minute stall.
chained_beat() { # <subject> <work> [args...] -> as beat_with, with a sibling beat
                 # already recorded in the shell that invokes the subject
  local subj="$1" w="$2"; shift 2
  ( cd "$w" && env AI_DLC_WAIT_BEAT_SECS=60 \
                   AI_DLC_WAIT_POLL_SECS=1 \
                   AI_DLC_WAIT_MARGIN_SECS=1 \
                   AI_DLC_MAX_WAIT_BEATS=6 \
    bash -c 'printf "%s" "$(date +%s)" > "_bmad-output/.wait-beats/.shell-$$" || exit 3
             s="$1"; shift
             bash "$s" "$@"
             exit $?' _ "$subj" "$@" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}

# The fixture's OWN mtime reader. Deliberately not borrowed from the subject: a
# fixture that sourced the subject's `mtime_of` would report the mark unchanged
# whenever that function broke, which is the mark assertion answering with the
# code it is measuring.
fx_mtime() {
  if stat -f "%m" . >/dev/null 2>&1; then stat -f "%m" "$1" 2>/dev/null || echo 0
  else stat -c "%Y" "$1" 2>/dev/null || echo 0; fi
}

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
# THE SIX MUTATIONS LIVE HERE, ONCE. Case 21 re-runs every one of them against the FLAGLESS
# path, so when each case ran in the same process it could reach for whatever the case above
# had left in $MUTDIR. Each case now runs in its own process and builds what it needs, and a
# second copy of these six sed programs would be a fork -- the defect half this fixture's
# subject exists to catch. One home, two readers.
#
# SETS $MUT_EXPR RATHER THAN PRINTING IT, for the reason `mutant` below already records and
# this function was written ignoring: `e="$(mutant_expr X)"` runs it in a SUBSHELL, so its
# `exit 2` on an unregistered name kills only that subshell. The caller then gets an EMPTY
# program, `sed ''` copies the file unchanged, and the `cmp -s` guard reports "matched
# nothing -- the code it targets was renamed", which is a true sentence about the wrong
# thing: a typo in a mutation NAME would read as a renamed SUBJECT. Caught by the driver
# battery, not by review.
MUT_EXPR=""
mutant_expr() { # <name> -> sets $MUT_EXPR to the sed program that removes that ONE mechanism
  case "$1" in
    grant-cap)               MUT_EXPR='s/ \&\& \[ "\$g" -lt "\$MAX_BEATS" \]//' ;;
    unprune-wait-beats)      MUT_EXPR='s/-o -name \.wait-beats/-o -name .no-such-name/' ;;
    unexclude-beat-inflight) MUT_EXPR="s/! -name '\.beat-inflight' //" ;;
    state-dir-guard)         MUT_EXPR='s/^  SD_ABS="\$(abs_of "\$STATE_DIR")"$/  SD_ABS=""/' ;;
    path-exists-check)       MUT_EXPR='s/\[ -e "\$1" \] ||/[ 1 ] ||/' ;;
    progress-sampling)       MUT_EXPR='/progressed_since "\$pg" \&\& PROGRESSED=1/d' ;;
    # THE THREE BELOW ARE ANCHORED ON INDENTATION, and that is load-bearing rather
    # than cosmetic. `if [ -n "$PROGRESS_PATHS" ]; then` occurs TWICE in the subject
    # -- once at column 0 for the state-dir argument guard, once at two spaces inside
    # the target loop -- and mutating the first would rewrite an argument check while
    # leaving the sampling gate alone: a mutant that applies cleanly to the wrong
    # line, which `cmp -s` cannot see. Measured before these were written: the
    # two-space anchor matches 1 line, the flush-left one matches 1, and an
    # impossible anchor matches 0.
    #
    # `restamp-ungated` rewrites the CONDITION to `[ 1 ]` instead of deleting the
    # `if`/`fi` pair, because `^    fi$` matches four lines in the subject and a
    # paired delete would take the wrong one.
    resample-gate)           MUT_EXPR='s/^  if \[ -n "\$PROGRESS_PATHS" \]; then$/  if [ -n "$PROGRESS_PATHS" ] \&\& [ "$MAY_SLEEP" -eq 1 ]; then/' ;;
    restamp-ungated)         MUT_EXPR='s/^    if \[ "\$MAY_SLEEP" -eq 1 \]; then$/    if [ 1 ]; then/' ;;
    # THE REDIRECT ONLY, NOT THE LINE. Deleting the line leaves `if ...; then` with
    # `fi` and nothing between them, which is a bash SYNTAX ERROR: the mutant then
    # exits 2 having executed nothing, the mark it was supposed to move is trivially
    # unchanged, and the assertion scores a kill it did not earn. Measured -- the
    # first draft of this mutation did exactly that, and it also showed up as three
    # phantom kills in cases that mutation has no business touching. `bash -n` in
    # `mutant` is now the standing guard.
    no-restamp)              MUT_EXPR='s%^      : > "\$pg" 2>/dev/null || true$%      : 2>/dev/null || true%' ;;
    # The over-correction case 16 exists for: a subject that grants whether or not
    # anything was written. Dropping the CALL and keeping the assignment is what "the
    # sample no longer decides anything" looks like from the outside.
    #
    # AIMED INSIDE THE `-n "$PROGRESS_PATHS"` BLOCK, and the first draft was not.
    # Seeding the initialiser -- `PROGRESSED=0` -> `PROGRESSED=1` -- looks equivalent
    # and is not: that line sits OUTSIDE the guard, because the exhaustion arm reads
    # PROGRESSED whether or not the flag was passed. So it granted on FLAGLESS joins
    # too, and case 22 caught it as a mutant reaching the default path. Caught by the
    # existing arm, on the first full run, not by review.
    grant-unconditional)     MUT_EXPR='s/^    progressed_since "\$pg" \&\& PROGRESSED=1$/    PROGRESSED=1/' ;;
    # THE ASYMMETRY THIS ONE GUARDS. A beat is charged only when the invocation
    # sleeps; a GRANT is charged whether it sleeps or not. So a chained sibling that
    # grants spends a grant and buys no wait, and if that were repeatable within one
    # Bash call a chained lead would burn every grant in a single turn and arrive at
    # NON-DELIVERY on a working teammate -- the same false non-delivery by another
    # route. What stops it is this line: the grant rewrites the counter to
    # MAX_BEATS-1, so the NEXT sibling in the same call is below the bound and never
    # reaches the grant arm at all. `> /dev/null` rather than deleting the line,
    # which would leave the `printf` writing to stdout and corrupt the output the
    # assertions read.
    grant-no-counter-rewrite) MUT_EXPR='s@^      printf .%s. "\$(( MAX_BEATS - 1 ))" > "\$c" 2>/dev/null || true$@      printf "%s" "$(( MAX_BEATS - 1 ))" > /dev/null 2>\&1 || true@' ;;
    *) echo "FIXTURE ERROR: no mutation registered for '$1'" >&2; exit 2 ;;
  esac
}
mutant() { # <name> -> sets $MUT to the mutant's path
  local name="$1"
  local expr
  mutant_expr "$name"
  expr="$MUT_EXPR"
  local m="$MUTDIR/$name.sh"
  sed "$expr" "$SUBJ" > "$m" || { echo "FIXTURE ERROR: sed failed for mutant '$name'" >&2; exit 2; }
  if cmp -s "$SUBJ" "$m"; then
    echo "FIXTURE ERROR: mutant '$name' matched nothing -- the code it targets was" >&2
    echo "  renamed or removed. Re-aim the mutation; do NOT delete the assertion." >&2
    exit 2
  fi
  # A MUTANT THAT WILL NOT PARSE IS NOT A MUTANT, AND IT SCORES KILLS IT DID NOT
  # EARN. A `sed` that removes the only statement from an `if` body leaves a syntax
  # error, so the copy exits 2 having executed NOTHING -- and "nothing happened" is
  # indistinguishable from the wrong behaviour every assertion here is looking for:
  # no output to grep, no file touched, no counter moved. Measured while writing the
  # chained-sibling mutants: one such mutant reported four kills, three of them in
  # cases its mutation cannot reach. `cmp -s` above cannot see this -- the edit
  # applied perfectly.
  if ! bash -n "$m" 2>/dev/null; then
    echo "FIXTURE ERROR: mutant '$name' does not parse -- the mutation removed a" >&2
    echo "  statement its enclosing block requires. A mutant that cannot RUN passes" >&2
    echo "  every assertion that looks for absence. Re-aim it to keep valid syntax." >&2
    exit 2
  fi
  MUT="$m"
}

# --- 1. the headline: a file from a prior sprint is not this join's answer ------
C01_stale() {
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
}

# --- 2. the yield the predicate fix must restore -------------------------------
# The marker is removed by an EXIT trap, so it only exists mid-beat: background the
# subject and poll. `kill -0` catches an exit that never wrote it at all, which is
# precisely the pre-fix behaviour.
C02_stale_marker() {
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
}

# --- 3. the teammate's real write, landing mid-beat -----------------------------
C03_arrives_mid_beat() {
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
}

# --- 4. a rounded-UP dispatch stamp must not become an unmeetable threshold -----
# MUTATION NOTE: this case reds only when BOTH guards in join_of are removed --
# `[ "$SINCE" -lt "$j_" ]` (apply --since only if it lowers) and `[ "$j_" -gt
# "$now_" ]` (never above now). Either alone defeats a future stamp, so mutating one
# leaves the case green. That is redundancy, not vacuity: verified by removing both,
# which reds it. Do not conclude this assertion is dead from a single-line mutation.
C04_since_clamp() {
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
}

# --- 5. --since may pull the threshold EARLIER (the post-compaction join) -------
C05_since_earlier() {
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
}

# --- 6. regression guards -------------------------------------------------------
C06_regression_guards() {
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
}

# --- 7. the counter is scoped to the bound it was counted against ---------------
# `counter-bound-reset` and `exhausted` are the same tree with one byte different:
# `.bound`. That byte is the whole mechanism, and the pair is what makes each
# assertion non-vacuous — deleting the self-heal reds ONLY this case, and a
# self-heal that wiped unconditionally would red ONLY `exhausted`.
C07_counter_bound_reset() {
W="$( bash "$SEED" counter-bound-reset )"
beat "$W"
if [ "$RC" -eq 0 ] && ! grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "counter-bound-reset: a counter spent against a DIFFERENT bound does not exhaust"
else bad "counter-bound-reset: rc $RC, NON-DELIVERY on a stale counter — a live teammate is re-dispatched on the first beat after a retune"; fi
if [ "$(cat "$W/_bmad-output/.wait-beats/.bound" 2>/dev/null)" = "6" ]; then
  ok "counter-bound-reset: .bound rewritten to the active bound"
else bad "counter-bound-reset: .bound not rewritten — the wipe repeats on every call, so no join can ever accumulate beats"; fi
rm -rf "$W"
}

# --- 8. the beat quantum is NOT the steering budget ------------------------------
# One env var carried both meanings until v0.167.0: the FOREGROUND gag bound
# (validate-steering-budget.sh Check A) and this BACKGROUNDED beat's sleep. The
# merge is invisible in normal operation — both are just "a number of seconds" —
# so it is asserted from both sides. Forward: the quantum alone decides the sleep.
C08_knob_split_forward() {
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
}

# Reverse: the steering budget cannot SHORTEN the beat either. Without this arm an
# alias in the other direction (STEERING_BUDGET winning when both are set) still
# passes the forward case whenever the budget happens to be the smaller number.
C09_knob_split_reverse() {
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
}

# --- 9. the marker is a LEASE, not the beat's end time ---------------------------
# Stop-hook Check 2b authorizes the lead's yield for as long as `.beat-inflight`
# holds a future epoch. Written ONCE with the beat's end time, a SIGKILLed beat
# (no EXIT trap) leaves that authorization standing for the whole remaining
# quantum with nothing alive to re-invoke the lead — a dead window that grows with
# the quantum, which is exactly what raising it to 600s would have multiplied.
# Re-stamped every poll, the lease expires ~3 polls after the beat dies.
C10_marker_goes_stale() {
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
}

# --- 10. an exhausted sequence with evidence of work is EXTENDED, not declared ---
# The clock says the teammate is dead; the filesystem says it wrote a file during
# the last beat. Both prior fixes for this failure only moved the clock, and S298
# then produced a legitimate 62-minute dispatch -- past even the raised ceiling.
# The message alone is not the assertion: `.grants` is checked, because a subject
# that printed PROGRESS and exhausted anyway would still re-dispatch a live
# teammate while reading as fixed.
C11_progress_extends() {
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
}

# --- 11. ...but the extension is BOUNDED. This is the case that keeps Check C ----
# true. Same evidence of work as case 10, every grant already spent. If this ever
# goes green-with-rc-0 the join can be held open forever by a teammate that writes
# and never delivers, and SKILL.md's Rule 26(c) claim that this script "can commit
# neither" failure becomes false with nothing to say so.
C12_progress_bounded() {
# Bound here rather than inherited: case 10 computed it when this file ran as one
# long script. Each case now runs in its own process, so an inherited name is an
# unset variable under `set -u`.
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"

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
}

# --- 12. machinery heartbeats in the watched tree are not evidence of work -------
# A teammate worktree carries its own `_bmad-output/`. Its `.wait-beats/` counters
# and `.beat-inflight` keep ticking whether or not the teammate is alive, and they
# are NOT this run's state dir, so the argument guard in case 13 cannot see them.
# Only the prune can. Without it, pointing at a worktree grants forever.
C13_progress_ignores_own_state() {
W="$( bash "$SEED" progress-ignores-own-state )"
beat "$W" --progress-path wt
if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "progress-ignores-own-state: wait-beat machinery does not count as work"
else bad "progress-ignores-own-state: rc $RC — the beat is reading its own heartbeat as the teammate's progress"; fi
if grep -q '^PROGRESS' "$BEATOUT"; then
  bad "progress-ignores-own-state: granted on .beat-inflight/.wait-beats churn alone"
else ok "progress-ignores-own-state: no PROGRESS line"; fi
rm -rf "$W"
}

# --- 13. the two ways this check could silently never fire ----------------------
# Both are argument errors, not runtime behaviour, because both produce a subject
# that runs clean forever while enforcing nothing. The CONTROL matters as much as
# the rejections: a subject that refused every --progress-path would satisfy the
# three exit-64 assertions and be entirely useless.
C14_progress_guards() {
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
}

# --- 14. the mutation proof, executed ------------------------------------------
# Each mutant removes ONE mechanism and asserts the subject then does the WRONG
# thing on the seed that mechanism exists for. That is a stronger claim than "the
# fixture reds": it names the behaviour the mechanism buys, so a reader can see what
# would ship without it. Every mutant is a copy; the subject is untouched throughout.
#
# The `.progress` mark: these reuse the same seeds as cases 10-13, which age the
# mark deliberately. See the seed file -- without that, `progressed_since` has
# nothing to compare against on its first call and every mutant looks equally dead.

C15_mut_grant_cap() {
mutant grant-cap
M="$MUT"
W="$( bash "$SEED" progress-bounded )"
beat_with "$M" "$W" --progress-path wt
if [ "$RC" -eq 0 ]; then
  ok "MUTANT grant-cap: without the cap a spent-grant join keeps extending — an unbounded wait"
else bad "MUTANT grant-cap: still rc $RC with the cap removed; the cap is not what bounds the extension"; fi
rm -rf "$W"
}

# Two prunes, mutated separately. Lumping them proves only that ONE of the two is
# load-bearing, and the seed ticks both `.wait-beats/<key>` and `.beat-inflight`.
C16_mut_unprune_wait_beats() {
mutant unprune-wait-beats
M="$MUT"
W="$( bash "$SEED" progress-ignores-own-state )"
beat_with "$M" "$W" --progress-path wt
if [ "$RC" -eq 0 ] && grep -q '^PROGRESS' "$BEATOUT"; then
  ok "MUTANT unprune-wait-beats: a teammate's own beat counters then read as work"
else bad "MUTANT unprune-wait-beats: rc $RC without the .wait-beats prune; the prune is not what excludes them"; fi
rm -rf "$W"
}

C17_mut_unexclude_beat_inflight() {
mutant unexclude-beat-inflight
M="$MUT"
W="$( bash "$SEED" progress-ignores-own-state )"
beat_with "$M" "$W" --progress-path wt
if [ "$RC" -eq 0 ] && grep -q '^PROGRESS' "$BEATOUT"; then
  ok "MUTANT unexclude-beat-inflight: a heartbeat marker then reads as work"
else bad "MUTANT unexclude-beat-inflight: rc $RC without the exclusion; it is not what excludes the marker"; fi
rm -rf "$W"
}

# Neutering SD_ABS rather than the comparison: the guard reads `[ -n "$SD_ABS" ]`,
# so an unresolvable state dir disables it wholesale. One line, unambiguously aimed.
C18_mut_state_dir_guard() {
mutant state-dir-guard
M="$MUT"
W="$( bash "$SEED" progress-guards )"
beat_with "$M" "$W" --progress-path _bmad-output
# `-eq 0`, not `-ne 64`: a mutant that failed to build exits 127, and `-ne 64`
# would read that as proof. The assertion has to name the outcome it expects.
if [ "$RC" -eq 0 ]; then
  ok "MUTANT state-dir-guard: _bmad-output is then accepted — progress becomes permanently true"
else bad "MUTANT state-dir-guard: rc $RC, expected a normal beat; the guard is not what rejects it"; fi
rm -rf "$W"
}

C19_mut_path_exists_check() {
mutant path-exists-check
M="$MUT"
W="$( bash "$SEED" progress-guards )"
beat_with "$M" "$W" --progress-path no-such-dir
if [ "$RC" -eq 0 ]; then
  ok "MUTANT path-exists-check: a typo'd path is then accepted and grants nothing, forever"
else bad "MUTANT path-exists-check: rc $RC, expected a normal beat; the check is not what rejects it"; fi
rm -rf "$W"
}

C20_mut_progress_sampling() {
mutant progress-sampling
M="$MUT"
W="$( bash "$SEED" progress-extends )"
beat_with "$M" "$W" --progress-path wt
if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "MUTANT progress-sampling: a demonstrably working teammate is declared non-delivered"
else bad "MUTANT progress-sampling: rc $RC without sampling; the grant is reachable by some other route"; fi
rm -rf "$W"
}

# The other half of the claim: none of the six changes the FLAGLESS path. Asserted
# rather than described, because "strictly additive" is exactly the sort of promise
# that quietly stops being true. `exhausted` is the case with the most to lose --
# it is the one state that still exits nonzero.
C21_mut_flagless_path() {
for mname in grant-cap unprune-wait-beats unexclude-beat-inflight state-dir-guard \
             path-exists-check progress-sampling \
             resample-gate restamp-ungated no-restamp grant-unconditional \
             grant-no-counter-rewrite; do
  mutant "$mname"
  W="$( bash "$SEED" exhausted )"
  beat_with "$MUT" "$W"
  if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
    ok "MUTANT $mname: the flagless path is untouched (exhausted still rc 1)"
  else bad "MUTANT $mname: rc $RC on a flagless join — this mutant reaches code the default path uses"; fi
  rm -rf "$W"
done
}

# --- 15. A CHAINED SIBLING MUST NOT REPORT A WORKING TEAMMATE AS NON-DELIVERY ----
# Cases 10-13 all run with MAY_SLEEP=1, and that is why the defect below shipped
# under a green fixture. The subject gated BOTH the progress SAMPLE and the mark
# RE-STAMP on MAY_SLEEP. Only the re-stamp needs it: sampling is a pure read. With
# both gated, a chained sibling arrived at the exhaustion arm with PROGRESSED forced
# to 0 -- and that arm is NOT gated on MAY_SLEEP, so it denied the grant and printed
# NON-DELIVERY for a teammate whose files were demonstrably being written. Rule 20
# turns that into a re-dispatch of a live teammate, which is the one failure this
# whole script exists to prevent.
#
# THE SOLE VARIABLE IS WHETHER A SIBLING BEAT RAN FIRST. The tree here is
# byte-identical to `progress-extends`, so nothing but MAY_SLEEP can explain a
# different verdict.
sibling_witness() { # <work> <label> -- a HARNESS control, not a claim about the subject
  # ONE `.shell-*` marker means the shell that seeded it is the shell the subject
  # looked up. TWO means the seed named a PID the subject never read (the shape an
  # `exec` in the wrapper would produce), the case ran with MAY_SLEEP=1, and every
  # assertion below it would be green about the wrong code path.
  local n
  n="$(find "$1/_bmad-output/.wait-beats" -maxdepth 1 -name '.shell-*' | grep -c . || true)"
  if [ "$n" = "1" ]; then
    ok "$2: CONTROL — one sibling marker, so the seeding shell IS the subject's parent"
  else bad "$2: $n sibling markers — the seeded marker is not the one the subject keyed on, so this case did not run with MAY_SLEEP=0"; fi
}

C22_chained_progress() {
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"
W="$( bash "$SEED" chained-progress )"
chained_beat "$SUBJ" "$W" --progress-path wt

sibling_witness "$W" "chained-progress"

# The line a lead actually reads. `-eq 0` and the absence of NON-DELIVERY are one
# claim stated twice on purpose: the exit code is what a Bash tool call surfaces,
# the line is what the lead acts on, and the pre-fix subject got both wrong.
if [ "$RC" -eq 0 ] && ! grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "chained-progress: a chained sibling does not declare non-delivery on a working teammate"
else bad "chained-progress: rc $RC with NON-DELIVERY — a live teammate is re-dispatched because a sibling beat ran first"; fi

if grep -q '^PROGRESS' "$BEATOUT"; then
  ok "chained-progress: stdout names PROGRESS — the lead is told not to re-dispatch"
else bad "chained-progress: no PROGRESS line; the grant is invisible to the lead"; fi

# Witnesses that this ran the NON-SLEEPING path all the way to its own exit, rather
# than reaching the grant by way of MAY_SLEEP=1.
case "$OUT" in
  *"a sibling beat already ran in this same Bash call"*)
    ok "chained-progress: the beat took the non-sleeping return, so MAY_SLEEP was 0" ;;
  *) bad "chained-progress: no chained-sibling NOTE — this beat slept, so it is not the case under test" ;;
esac

# The message is not the mechanism. A subject that printed PROGRESS and granted
# nothing would still re-dispatch on the next beat while reading as fixed.
if [ "$(cat "$W/_bmad-output/.wait-beats/${KEY}.grants" 2>/dev/null)" = "1" ]; then
  ok "chained-progress: one grant charged — the extension is counted, not free"
else bad "chained-progress: .grants not 1 — an uncounted extension is an unbounded wait"; fi
# THIS ASSERTION CARRIES MORE THAN IT SAYS, and case 23 is the mutant that shows it.
# A grant is charged whether or not the invocation slept, while a BEAT is charged only
# when it sleeps. The counter rewrite is the only thing that stops a second sibling in
# the same Bash call from reaching the grant arm again: at MAX_BEATS-1 it is below the
# bound. Without it a chained lead burns every grant in one turn and lands on
# NON-DELIVERY with a teammate still writing.
if [ "$(cat "$W/_bmad-output/.wait-beats/${KEY}" 2>/dev/null)" = "5" ]; then
  ok "chained-progress: the counter is set to MAX_BEATS-1 — the next sibling in this call cannot grant again"
else bad "chained-progress: counter not MAX_BEATS-1; a second chained sibling can grant in the same call and burn the whole grant budget in one turn"; fi
rm -rf "$W"
}

# --- 16. ...and the near-miss stays quiet ---------------------------------------
# Same chained sibling, same spent sequence, one fact removed: nothing under the
# worktree is newer than the mark. Without this arm, a subject that granted
# UNCONDITIONALLY -- which is one deleted comparison away -- would satisfy case 15
# and read as fixed.
C23_chained_noprogress() {
W="$( bash "$SEED" chained-noprogress )"
chained_beat "$SUBJ" "$W" --progress-path wt

sibling_witness "$W" "chained-noprogress"

if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "chained-noprogress: with no evidence of work the wait still ends"
else bad "chained-noprogress: rc $RC — a chained sibling now grants without evidence, which is an unbounded wait (Rule 29, Check C)"; fi
if grep -q '^PROGRESS' "$BEATOUT"; then
  bad "chained-noprogress: PROGRESS granted on a tree where nothing was written"
else ok "chained-noprogress: no PROGRESS line — the grant discriminates"; fi
rm -rf "$W"
}

# --- 17. the window the original gate protected is STILL protected ---------------
# This is the arm that stops "delete the gate" passing as the fix. A non-sleeping
# sibling must not re-stamp the mark: re-stamping shrinks the observation window to
# nothing, so the NEXT beat asks "was anything written since a moment ago" and
# reports a working teammate as idle -- the same false non-delivery from the other
# direction.
#
# The counter is BELOW the bound here, so the grant path never runs. At the bound it
# rewrites the counter too, and two writes in one observation cannot be attributed.
C24_chained_window() {
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"
W="$( bash "$SEED" chained-window )"
MARK="$W/_bmad-output/.wait-beats/${KEY}.progress"
M0="$( fx_mtime "$MARK" )"
[ "$M0" != "0" ] || { echo "FIXTURE ERROR: chained-window seeded no .progress mark to measure" >&2; exit 2; }

chained_beat "$SUBJ" "$W" --progress-path wt
if [ "$( fx_mtime "$MARK" )" = "$M0" ]; then
  ok "chained-window: a non-sleeping sibling leaves the mark alone — the window stays open"
else bad "chained-window: the mark was re-stamped by a beat that did not sleep; the window is shrunk to nothing and the next beat reads a working teammate as idle"; fi

# THE BEHAVIOURAL HALF, because an mtime is a proxy and the outcome is the claim. A
# FOLLOWING beat must still see the window its sleeping predecessor opened. Re-seed
# the counter to the bound so the answer is a verdict the lead would read; if the
# mark had been re-stamped above, `wip.txt` would no longer be newer than it and
# this second beat would print NON-DELIVERY instead.
#
# THE FOLLOWING BEAT IS A SLEEPING ONE, AND THAT IS WHAT KEEPS THIS ARM THE WINDOW'S
# AND NOT THE SAMPLE'S. Chained, it would also need the sample to be ungated, so
# re-gating the sample would red this case as well as case 15 -- two failures for one
# mutant, which means one of the two arms is not measuring what it says. Case 15 OWNS
# the sample gate. Here MAY_SLEEP is 1, the sample runs under either build, and the
# only thing left that can change the verdict is whether the window survived.
printf '6' > "$W/_bmad-output/.wait-beats/${KEY}"
beat "$W" --progress-path wt
case "$OUT" in
  *"a sibling beat already ran in this same Bash call"*)
    bad "chained-window: the following beat was itself chained — this arm then also depends on the sample gate, which case 15 owns" ;;
  *) ok "chained-window: CONTROL — the following beat is a sleeping one, so the sample runs either way" ;;
esac
if [ "$RC" -eq 0 ] && grep -q '^PROGRESS' "$BEATOUT"; then
  ok "chained-window: the following beat still observes the earlier window and grants"
else bad "chained-window: rc $RC and no PROGRESS on the following beat — the window did not survive the sibling"; fi
rm -rf "$W"
}

# --- 18. the other direction: a beat that DOES sleep re-stamps the mark ----------
# Case 17 alone would be satisfied by a subject that never re-stamped at all, and
# that subject grants forever: the mark ages without bound, so anything written
# since the join armed keeps reading as this beat's progress. The re-stamp is what
# makes the signal a DELTA. This is the only new case that sleeps.
C25_sleeping_restamp() {
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"
W="$( bash "$SEED" sleeping-restamp )"
MARK="$W/_bmad-output/.wait-beats/${KEY}.progress"
M0="$( fx_mtime "$MARK" )"
[ "$M0" != "0" ] || { echo "FIXTURE ERROR: sleeping-restamp seeded no .progress mark to measure" >&2; exit 2; }

beat "$W" --progress-path wt
if [ "$( fx_mtime "$MARK" )" -gt "$M0" ]; then
  ok "sleeping-restamp: a sleeping beat re-stamps the mark — progress stays a delta, not a state"
else bad "sleeping-restamp: the mark was not re-stamped; the window never closes and every later beat grants on the same old write"; fi
rm -rf "$W"
}

# --- 19. the grant is still bounded on the chained path -------------------------
# Case 11 proves the cap on the sleeping path. The fix widened WHO reaches the grant
# arm, so the cap has to be asserted for the newly-reaching caller too -- otherwise
# a chained sibling is a route around Rule 29's Check C and SKILL.md's Rule 26(c)
# claim becomes false with nothing to say so.
C26_chained_grant_bounded() {
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"
W="$( bash "$SEED" progress-bounded )"
chained_beat "$SUBJ" "$W" --progress-path wt
if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "chained-grant-bounded: a chained sibling with every grant spent still ends the wait"
else bad "chained-grant-bounded: rc $RC — the chained path is a route around the grant cap"; fi
# THE `grants are spent` NOTE IS DELIBERATELY NOT ASSERTED HERE. It requires
# PROGRESSED=1, so re-gating the sample reds it -- and case 15 owns that gate. Case
# 11 already asserts the NOTE, on the sleeping path where nothing else can move it.
# What is new on the chained path is the CAP, and that is what this case measures.
if [ "$(cat "$W/_bmad-output/.wait-beats/${KEY}.grants" 2>/dev/null)" = "6" ]; then
  ok "chained-grant-bounded: grant counter held at the cap"
else bad "chained-grant-bounded: grant counter moved past the cap"; fi
rm -rf "$W"
}

# --- 20. the mutation proof for cases 15-19 -------------------------------------
# Each of the three restores one half of the defect, and they are separate because
# the fix has two halves: the sample lost its gate and the re-stamp kept one.
# Reverting them together would produce a mutant that proves whichever half was left
# in place -- and it comes out green.

# THE DEFECT ITSELF, reinstated. This is the pre-fix subject at the one line that
# changed, so this mutant is the measurement that case 15 was worth writing.
C27_mut_resample_gate() {
mutant resample-gate
M="$MUT"
W="$( bash "$SEED" chained-progress )"
chained_beat "$M" "$W" --progress-path wt
if [ "$RC" -eq 1 ] && grep -q '^NON-DELIVERY' "$BEATOUT"; then
  ok "MUTANT resample-gate: gating the SAMPLE on MAY_SLEEP declares a demonstrably working teammate non-delivered"
else bad "MUTANT resample-gate: rc $RC with the sample re-gated; the ungated sample is not what reaches the grant"; fi
rm -rf "$W"
}

# The opposite over-correction: a fix that simply deleted the gate. The grant works,
# and the window it depends on is destroyed by every non-sleeping sibling.
C28_mut_restamp_ungated() {
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"
W="$( bash "$SEED" chained-window )"
MARK="$W/_bmad-output/.wait-beats/${KEY}.progress"
M0="$( fx_mtime "$MARK" )"
mutant restamp-ungated
M="$MUT"
chained_beat "$M" "$W" --progress-path wt
if [ "$( fx_mtime "$MARK" )" != "$M0" ]; then
  ok "MUTANT restamp-ungated: without the re-stamp gate a non-sleeping sibling shrinks the window"
else bad "MUTANT restamp-ungated: the mark is unchanged with the gate removed; the gate is not what protects the window"; fi
rm -rf "$W"
}

# And the subtraction the other two would both tolerate: no re-stamp at all. It
# passes cases 15, 16, 17 and 19 -- only case 18 sees it.
C29_mut_no_restamp() {
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"
W="$( bash "$SEED" sleeping-restamp )"
MARK="$W/_bmad-output/.wait-beats/${KEY}.progress"
M0="$( fx_mtime "$MARK" )"
mutant no-restamp
M="$MUT"
beat_with "$M" "$W" --progress-path wt
if [ "$( fx_mtime "$MARK" )" = "$M0" ]; then
  ok "MUTANT no-restamp: with the re-stamp deleted a sleeping beat never closes the window"
else bad "MUTANT no-restamp: the mark still moved; the deleted line is not what re-stamps it"; fi
rm -rf "$W"
}

# Case 16's mutant. Without it, case 16 establishes that the arm is quiet on a tree
# with no progress -- but not that anything in the subject is doing the discriminating.
C30_mut_grant_unconditional() {
mutant grant-unconditional
M="$MUT"
W="$( bash "$SEED" chained-noprogress )"
chained_beat "$M" "$W" --progress-path wt
if [ "$RC" -eq 0 ] && grep -q '^PROGRESS' "$BEATOUT"; then
  ok "MUTANT grant-unconditional: a subject that grants without evidence extends the wait forever"
else bad "MUTANT grant-unconditional: rc $RC with PROGRESSED forced to 1; the sample is not what gates the grant"; fi
rm -rf "$W"
}

# Case 15's counter assertion, proven load-bearing. Without the rewrite the grant arm
# stays reachable, so a SECOND sibling in the same Bash call grants again -- and the
# grant budget empties in one turn while the beat budget is untouched.
C32_mut_grant_no_counter_rewrite() {
KEY="$( printf '%s' deliv.md | cksum | tr -d ' \t' | cut -c1-16 )"
mutant grant-no-counter-rewrite
M="$MUT"
W="$( bash "$SEED" chained-progress )"
chained_beat "$M" "$W" --progress-path wt
if [ "$(cat "$W/_bmad-output/.wait-beats/${KEY}" 2>/dev/null)" = "6" ]; then
  ok "MUTANT grant-no-counter-rewrite: the counter stays at the bound, so the next sibling in this call grants again"
else bad "MUTANT grant-no-counter-rewrite: counter is not at the bound with the rewrite removed; something else is holding it down"; fi
rm -rf "$W"
}

# --- 21. this fixture's verdict may not depend on the cwd it was launched from ---
# The suite runs `bash core/fixtures/<name>/run.sh` FROM THE REPO ROOT, so every
# case above has only ever been observed at one cwd. That cuts both ways in this
# repo: a fixture can be green only from the root, and it can also be green only
# because decoy files happen to exist there. Everything here resolves through HERE
# (absolute, from `$0`) and through trees that seed.sh makes under mktemp, so the
# claim is that cwd cannot reach any of it -- asserted rather than assumed, in the
# fixture's own arms, because it does not inherit that from how the suite is driven.
#
# The child is invoked by ABSOLUTE path. A relative `$0` from a foreign cwd cannot
# resolve, and that is a property of every script rather than something to assert.
C31_cwd_invariance() {
SELF_ABS="$HERE/$(basename "$0")"
out="$( cd / && bash "$SELF_ABS" --run-one C23_chained_noprogress 2>&1 )"
rc=$?
if [ "$rc" -eq 0 ]; then
  ok "cwd-invariance: a case reaches the same verdict launched from /"
else bad "cwd-invariance: rc $rc from cwd=/ — some arm above is reading a path relative to the repo root, so the suite's cwd is load-bearing: $out"; fi
# The CONTROL. `-eq 0` alone is also what an empty run scores, and a case that
# printed nothing is the exact shape of a resolution failure that exited quietly.
n="$( printf '%s\n' "$out" | grep -c '^  ok' || true )"
if [ "$n" = "3" ]; then
  ok "cwd-invariance: CONTROL — all three of that case's assertions ran from /, not zero of them"
else bad "cwd-invariance: $n assertions from cwd=/ , expected 3 — the case exited without running, which scores as clean"; fi
}

# ---------------------------------------------------------------------------
# THE DRIVER
# ---------------------------------------------------------------------------
# `--run-one <case>` is one case, in one process, with its own temp state. It is the unit the
# pool schedules and it is how a human runs a single case while working on it.
if [ "${1:-}" = "--run-one" ]; then
  FN="${2:-}"
  declare -F "$FN" >/dev/null 2>&1 || {
    echo "FIXTURE ERROR: --run-one needs a case function name; '$FN' is not one" >&2
    exit 2
  }
  setup_tmp
  echo "wait-stale-deliverable:"   >/dev/null   # the header belongs to the parent, not here
  "$FN"
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

# THE CASE LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order, with a zero
# guard. A hand-written list would be the defect this fixture's own subject is about: a case
# dropped from it runs nothing, prints nothing, and 20 greens read exactly like 21.
NAMES="$(grep -oE '^C[0-9]{2}_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
if [ "$N_LISTED" -lt 10 ]; then
  echo "FIXTURE ERROR: derived $N_LISTED case(s) from this file — the C<nn>_ naming grammar moved" >&2
  exit 2
fi

echo "wait-stale-deliverable:"

OUT="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$OUT"' EXIT
SELF="$HERE/$(basename "$0")"

# EIGHT. This pool nests inside the pre-push suite's, so a knob here would multiply against a
# knob there; the cases sleep rather than compute, so eight of them cost about one core.
JOBS=8
printf '%s\n' "$NAMES" > "$OUT/list"
AI_DLC_WS_SELF="$SELF" AI_DLC_WS_OUT="$OUT" \
  xargs -P "$JOBS" -I{} bash -c '
    n="$1"
    bash "$AI_DLC_WS_SELF" --run-one "$n" > "$AI_DLC_WS_OUT/$n" 2> "$AI_DLC_WS_OUT/$n.err"
    printf %s $? > "$AI_DLC_WS_OUT/$n.rc"
  ' _ {} < "$OUT/list"

# Rendered in SOURCE order, never completion order, so the output is byte-comparable against
# the serial version. A MISSING VERDICT IS A FAILURE: serially a case that never ran could not
# print an `ok`, because the loop and the report were the same thing. With a pool they are not,
# and a case that exits nonzero having printed nothing would add zero to the count -- which is
# what a clean case adds.
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ ! -f "$OUT/$n.rc" ]; then
    printf '  FAIL  %s produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one\n' "$n"
    fails=$((fails + 1))
    continue
  fi
  cat "$OUT/$n"
  [ -s "$OUT/$n.err" ] && cat "$OUT/$n.err" >&2
  wrc="$(cat "$OUT/$n.rc")"
  # 2 IS NOT 1. `FIXTURE BROKEN` and `an assertion regressed` are different answers, and this
  # file's helpers have always used exit 2 for the first. Running a case in a worker would
  # otherwise collapse them: the parent would see a nonzero rc, charge one assertion, and exit
  # 1 — reporting a regression where the truth is that nothing was tested.
  if [ "$wrc" = "2" ]; then broken=1; fi
  if [ "$wrc" != "0" ]; then
    c="$(grep -c '^  FAIL' "$OUT/$n" || true)"
    [ "$c" -gt 0 ] || { printf '  FAIL  %s exited nonzero without an assertion line — the case did not run to a verdict\n' "$n"; c=1; }
    fails=$((fails + c))
  fi
done < "$OUT/list"

if [ "$broken" -ne 0 ]; then
  echo "wait-stale-deliverable: FIXTURE BROKEN — a case could not run to a verdict" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "wait-stale-deliverable: PASS"
  exit 0
fi
echo "wait-stale-deliverable: ${fails} assertion(s) FAILED" >&2
exit 1
