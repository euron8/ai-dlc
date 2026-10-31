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
#
# MUTANT MATRIX. A mutant is a copy of the subject with ONE mechanism removed; an ARM is a positive case
# (C<nn>_*) that asserts the subject behaves correctly, run with that copy as the subject. A mutant is
# dead on an arm iff the arm TRIPS (exits 1 having printed a FAIL line) under it. PER PUSH each mutant
# runs its DECIDING arm, which must trip, and its TWIN, a different arm the measured matrix shows GREEN
# for it, which must stay green: the kill is confined to the deciding arm. The kill is emitted through
# mutant_killed (lib/mutant.sh) behind the same-run pass of the unmutated deciding arm, of the twin, and
# of the unmutated copy MX0. `--matrix` runs every mutant (and MX0) on EVERY arm and prints one MATRIX
# row per cell, polarity explicit, from the sourced lib/matrix.sh. These header lines ARE the table the
# driver reads, so there is no second copy to drift. The matrix is re-measured whenever an arm or a
# mutant is added or changed, from the repo root, with AI_DLC_VERDICT_STORE set to a fresh mktemp dir;
# it is not run through hermetic-run.sh, which runs under env -i and forwards no argument.
# C31 is not an arm: it re-launches C23 from / and takes no subject.
#
# MUTANT-MATRIX-REMEASURE bash core/fixtures/wait-stale-deliverable/run.sh --matrix
# MUTANT-MATRIX-DYNAMIC table-loop why=the driver reads the MUTANT-MATRIX rows below back from this file and passes each name to mutant_killed as a variable, so every name the loop produces has its own row
# MUTANT-MATRIX-CONTROL MX0 why=the unmutated copy must trip no arm; it is the base pass every kill is gated on
# MUTANT-MATRIX grant-cap decides=C12_progress_bounded twins=C11_progress_extends
# MUTANT-MATRIX unprune-wait-beats decides=C13_progress_ignores_own_state twins=C11_progress_extends
# MUTANT-MATRIX unexclude-beat-inflight decides=C13_progress_ignores_own_state twins=C11_progress_extends
# MUTANT-MATRIX state-dir-guard decides=C14_progress_guards twins=C13_progress_ignores_own_state
# MUTANT-MATRIX path-exists-check decides=C14_progress_guards twins=C13_progress_ignores_own_state
# MUTANT-MATRIX progress-sampling decides=C11_progress_extends twins=C13_progress_ignores_own_state
# MUTANT-MATRIX resample-gate decides=C22_chained_progress twins=C23_chained_noprogress
# MUTANT-MATRIX restamp-ungated decides=C24_chained_window twins=C25_sleeping_restamp
# MUTANT-MATRIX no-restamp decides=C25_sleeping_restamp twins=C24_chained_window
# MUTANT-MATRIX grant-unconditional decides=C23_chained_noprogress twins=C22_chained_progress
# MUTANT-MATRIX grant-no-counter-rewrite decides=C22_chained_progress twins=C23_chained_noprogress
# MUTANT-MATRIX lease-trap-unconditional decides=C33_lease_handoff twins=C38_lease_early
# MUTANT-MATRIX lease-no-heir decides=C33_lease_handoff twins=C38_lease_early
# MUTANT-MATRIX lease-always-put decides=C36_lease_noclobber twins=C38_lease_early
# MUTANT-MATRIX lease-no-early decides=C38_lease_early twins=C44_bare_epoch
# MUTANT-MATRIX no-join-memo decides=C40_two_beats_one_path twins=C42_memo_single
# MUTANT-MATRIX since-kept-on-delivery decides=C42_memo_single twins=C44_bare_epoch
# MUTANT-MATRIX preupgrade-taken decides=C44_bare_epoch twins=C38_lease_early
# MUTANT-MATRIX lease-end-time decides=C10_marker_goes_stale twins=C44_bare_epoch
#
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
# PRECONDITIONS ARE NOT TARGETS. A precondition (the beats ran in their own shells, A was asleep when the
# marker was read, the kill came early enough, ...) is a fact about the HARNESS. pre_bad counts one, and a
# --run-one worker that saw any exits 2 (FIXTURE BROKEN), never 1 (an assertion regressed), so a mutant
# cell whose precondition failed can never be read as a kill. pre_ok also records its text in PRE_FILE (the
# driver's per-cell side channel) so the driver can re-print it under the mutant's name and compare its count
# against the same arm's count on the real subject.
PRE_FILE=""; pre_fails=0
pre_ok()  { ok "$1"; if [ -n "$PRE_FILE" ]; then printf '%s\n' "$1" >> "$PRE_FILE"; fi; }
pre_bad() { bad "$1"; pre_fails=$((pre_fails+1)); }

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
#
# NO ASSERTION HERE READS A WALL CLOCK, AND THAT IS THE OPERATOR'S RULING, NOT A STYLE. The
# cases that ask "did the beat sleep" used to answer it with `ELAPSED -ge 2`, `-le 1`, `-le 10`,
# `-ge 6`: a number of seconds standing in for a yes/no fact, and a number the box's load moves.
# Under a loaded pool a beat that returned at once could read 2s, and one that slept could be
# scheduled late enough to read anything at all. The fact is binary and the subject has exactly
# ONE place it can be observed -- its poll loop's `sleep "$POLL"` is the only `sleep` it runs --
# so `sleep_stub` puts a recording `sleep` first on the beat's PATH and the arm reads the record:
# the beat entered its poll sleep, or it did not. Every arm that asserts NO record also proves
# the stub records, on the same PATH in the same case, so a stub that silently stopped logging
# cannot pass as a beat that never slept.
setup_tmp() {
  BEATOUT="$(mktemp)"
  MUTDIR="$(mktemp -d 2>/dev/null || mktemp -d -t wait-mutants)"
  trap 'rm -f "$BEATOUT"; rm -rf "$MUTDIR"' EXIT
}
# BW_Q / BW_PATH: the quantum and the PATH one beat runs with. Unset, a beat runs with quantum 1
# against MARGIN 1, so its deadline is `now` and it leaves the poll loop at the first check
# WITHOUT sleeping. Every verdict a default beat is asked for (WAITING, NON-DELIVERY, PROGRESS,
# the counter, the .bound, the mark) is decided outside the loop, and a beat is charged because
# the invocation MAY sleep, not because the loop ran, so no default-beat arm reads the clock. A
# case that asserts WHETHER a beat slept sets BW_Q itself and runs under the recording stub; a case that needs the sleep record or a
# quantum no scheduling delay can cross sets them for its own beat and unsets them after.
BW_Q=""; BW_PATH=""
beat_with() { # <subject> <work> [extra args...] -> writes $BEATOUT; sets RC and OUT
  local subj="$1" w="$2"; shift 2
  ( cd "$w" && env PATH="${BW_PATH:-$PATH}" \
                   AI_DLC_WAIT_BEAT_SECS="${BW_Q:-1}" \
                   AI_DLC_WAIT_POLL_SECS=1 \
                   AI_DLC_WAIT_MARGIN_SECS=1 \
                   AI_DLC_MAX_WAIT_BEATS=6 \
    AI_DLC_PROJECT_ROOT="$PWD" bash "$subj" "$@" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}

# ---------------------------------------------------------------------------
# THE SLEEP RECORD. `sleep_stub <dir>` writes `<dir>/bin/sleep`, which appends its argument to
# `<dir>/sleep.log` and then EXECS the real sleep, so a beat under it behaves exactly as it does
# without it and leaves a line per poll sleep it entered. It sets STUB_PATH (the PATH to hand a
# beat) and STUB_LOG. The real `sleep` and `bash` are resolved HERE, before anything is
# prepended, and baked in as absolute paths: under the hermetic runner PATH is a tool farm and
# `env -i`, so nothing about the stub may depend on a lookup it would make itself.
#
# THE STUB'S OWN CONTROL IS `stub_works`: one `sleep 0` through STUB_PATH must add exactly one
# line. An arm that asserts "no record" runs it first, in the same case, on the same PATH --
# otherwise a stub that was never on the beat's PATH (or never executable) reads exactly like a
# beat that never slept.
STUB_PATH=""; STUB_LOG=""
# MODES. `real` (default) execs the real sleep with its own argument, for the cases whose subject
# IS a beat parked in a long poll (frozen, killed, woken on purpose). `fast` records the call and
# sleeps 0.05s whatever the argument, for a case that only needs the beat to ENTER a poll sleep
# and then see a write. `gate` records and then blocks until `<dir>/release` exists, so the case
# decides the moment the beat wakes and no clock does.
sleep_stub() { # <dir> [real|fast|gate]
  local real_sleep real_bash mode="${2:-real}" body
  real_sleep="$(command -v sleep)"; real_bash="$(command -v bash)"
  [ -n "$real_sleep" ] && [ -n "$real_bash" ] || { echo "FIXTURE ERROR: cannot resolve sleep/bash for the sleep stub" >&2; exit 2; }
  mkdir -p "$1/bin" || { echo "FIXTURE ERROR: cannot create the sleep stub dir" >&2; exit 2; }
  STUB_LOG="$1/sleep.log"; : > "$STUB_LOG"
  case "$mode" in
    real) body="$(printf 'exec "%s" "$@"' "$real_sleep")" ;;
    fast) body="$(printf 'exec "%s" 0.05' "$real_sleep")" ;;
    gate) body="$(printf 'while [ ! -e "%s/release" ]; do "%s" 0.02; done' "$1" "$real_sleep")" ;;
    *) echo "FIXTURE ERROR: unknown sleep stub mode '$mode'" >&2; exit 2 ;;
  esac
  printf '#!%s\nprintf "%%s\\n" "$*" >> "%s"\n%s\n' "$real_bash" "$STUB_LOG" "$body" > "$1/bin/sleep"
  chmod +x "$1/bin/sleep" || { echo "FIXTURE ERROR: cannot make the sleep stub executable" >&2; exit 2; }
  STUB_PATH="$1/bin:$PATH"
}
stub_lines() { [ -f "$STUB_LOG" ] || { echo 0; return; }; awk 'END { print NR }' "$STUB_LOG"; }
stub_works() { # -> 0 when one `sleep 0` through STUB_PATH adds exactly one record
  local n0 n1
  n0="$(stub_lines)"
  env PATH="$STUB_PATH" sleep 0 || return 1
  n1="$(stub_lines)"
  [ "$n1" = "$(( n0 + 1 ))" ]
}
# DELIVERY GATED ON THE SLEEP, NOT ON A CLOCK. `( sleep 2; write ) &` raced the beat's deadline:
# under load the write could land after the beat gave up, or before it had armed. This writer
# waits until the stub has recorded the beat's first poll sleep, then writes -- so the write is
# strictly inside the beat's poll loop, whatever the load. It also stops when `<stop>` appears,
# which the case creates once the beat has returned, so a beat that never slept cannot leave
# the writer looping. Sets DW to the writer's pid.
DW=""
deliver_on_sleep() { # <file> <stop>
  ( while [ ! -s "$STUB_LOG" ] && [ ! -e "$2" ]; do sleep 0.02; done
    [ -s "$STUB_LOG" ] && printf 'the actual answer for this sprint\n' > "$1" ) &
  DW=$!
}
end_writer() { # <stop>
  : > "$1"; wait "$DW" 2>/dev/null || true
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
             AI_DLC_PROJECT_ROOT="$PWD" bash "$s" "$@"
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
    # ---- the lease and per-process-memo mutations (cases 33-45) ----------------------
    # The pre-lease EXIT trap: every beat deletes the shared marker on exit, holder or not.
    lease-trap-unconditional) MUT_EXPR="s#^trap 'lease_release' EXIT\$#trap 'rm -f \"\$BEAT_MARKER\" 2>/dev/null || true' EXIT#" ;;
    # The holder releases without looking for an heir: it deletes the marker whenever it holds
    # it. Anchored on the heir branch's own line; the `else rm` line beneath it stays.
    lease-no-heir)            MUT_EXPR='s/^    if \[ -n "\$lr_heir_" \]; then lease_put .*$/    if false; then :/' ;;
    # Every beat takes the marker on every beat_alive, live holder or not.
    lease-always-put)         MUT_EXPR='s/^  if \[ "\$ba_pid_" = "\$WD_SELF_PID" \] || lease_holder_dead "\$ba_pid_"; then lease_put "\$ba_e_" "\$WD_SELF_PID"; fi$/  lease_put "$ba_e_" "$WD_SELF_PID"/' ;;
    # The early lease, deleted: the bare `beat_alive` directly beneath the trap line. The
    # in-loop call before the sleep is ALSO a bare column-0 `beat_alive`, so the delete is
    # keyed on the line after the trap rather than on the text, which matches both.
    lease-no-early)           MUT_EXPR="/^trap 'lease_release' EXIT\$/{n;/^beat_alive\$/d;}" ;;
    # The per-process join-epoch memo, removed: every join_of re-reads the shared sidecar.
    no-join-memo)             MUT_EXPR='s/^  if \[ -n "\$jm_" \]; then printf .%s. "\$jm_"; return 0; fi$/  :/' ;;
    # Keeping `.since` when a path delivers, the shape a fix for two beats on one path could
    # take instead of the memo. Case 42 owns it: a later beat armed without --since then reads
    # a delivered file as this join's answer. Aimed at the post-sleep report's cleanup (four-space indent
    # and `${c}.progress`), not the pre-sweep's (`$pg`), because that is where a mid-beat
    # delivery is consumed.
    since-kept-on-delivery)   MUT_EXPR='s/^    rm -f "\$c" "\$s" "\${c}\.progress"/    rm -f "$c" "${c}.progress"/' ;;
    # A live pid-less (pre-upgrade) lease is taken instead of left alone.
    preupgrade-taken)         MUT_EXPR='/^  \[ -n "\$ba_pid_" \] || return 0  *# a live pre-upgrade lease/d' ;;
    # The pre-v0.81 marker: the lease is the beat's END time, fixed at its first write and
    # re-written unchanged at every poll. `${BA_T0_:=...}` captures the first call's clock and
    # every later call reuses it, so re-stamping still happens and only the VALUE is wrong --
    # the defect case 10 exists for, and the one its old seconds-of-slack bound stood in for.
    lease-end-time)           MUT_EXPR='s/^  ba_e_=\$(( \$(date +%s) + 3 \* POLL ))$/  ba_e_=$(( ${BA_T0_:=$(date +%s)} + BUDGET ))/' ;;
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
# The beat is HELD in its first poll sleep (gate stub) until the marker has been observed, then the
# real write is made and the gate opened, so it delivers and leaves through its normal EXIT trap.
# No quantum is waited out and no clock decides either moment.
sleep_stub "$W/.stub" gate
( cd "$W" && env PATH="$STUB_PATH" AI_DLC_WAIT_BEAT_SECS=60 AI_DLC_WAIT_POLL_SECS=1 \
                 AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 \
    AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" deliv.md >/dev/null 2>&1 ) & PID=$!
seen=0
for _ in $(seq 1 3000); do
  [ -f "$W/_bmad-output/.beat-inflight" ] && { seen=1; break; }
  kill -0 "$PID" 2>/dev/null || break
  sleep 0.02
done
printf 'the actual answer for this sprint\n' > "$W/deliv.md"
: > "$W/.stub/release"
wait "$PID" 2>/dev/null || true
if [ "$seen" -eq 1 ]; then ok "stale-marker: .beat-inflight live during the beat (lead may yield)"
else bad "stale-marker: no .beat-inflight — the lead cannot yield and will poll in foreground"; fi
if [ -f "$W/_bmad-output/.beat-inflight" ]; then
  bad "stale-marker: marker survived the beat — a dead beat would authorize a silent stall"
else ok "stale-marker: marker cleared on exit"; fi
rm -rf "$W"
}

# --- 3. the teammate's real write, landing mid-beat -----------------------------
# QUANTUM 60, AND THE PASSING PATH NEVER SPENDS IT. The write is gated on the beat's first poll
# sleep (deliver_on_sleep), so a correct beat wakes once, sees the write, and returns. The large
# quantum only means no scheduling delay between the stub's record and the write can push the
# write past the beat's deadline -- which at quantum 4 it could, and read as a missed delivery.
C03_arrives_mid_beat() {
W="$( bash "$SEED" arrives-mid-beat )"
sleep_stub "$W/.stub" fast
deliver_on_sleep "$W/deliv.md" "$W/.stub/stop"
BW_Q=60; BW_PATH="$STUB_PATH"
beat "$W"
BW_Q=""; BW_PATH=""
end_writer "$W/.stub/stop"
if [ "$RC" -eq 0 ] && grep -q '^DELIVERED' "$BEATOUT"; then
  ok "arrives-mid-beat: DELIVERED once the real write lands"
else bad "arrives-mid-beat: rc $RC, no DELIVERED line — a genuine delivery was missed"; fi
# No sleep record means the poll loop broke on the stale file's mere presence while
# the sweep applied the fresh predicate: a beat charged, none slept.
if [ "$(stub_lines)" -ge 1 ]; then ok "arrives-mid-beat: beat entered its poll sleep ($(stub_lines) record(s)) — predicates agree"
else bad "arrives-mid-beat: the beat never entered its poll sleep — poll loop and sweep disagree on delivery"; fi
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
# The write is gated on the beat's first poll sleep (deliver_on_sleep), not on `sleep 2`: it lands
# strictly inside the poll loop whatever the load, and no second of clock is spent waiting for it.
sleep_stub "$W/.stub" fast
deliver_on_sleep "$W/deliv.md" "$W/.stub/stop"
BW_Q=20; BW_PATH="$STUB_PATH"
beat "$W" --since "$FUT"
BW_Q=""; BW_PATH=""
end_writer "$W/.stub/stop"
if [ "$RC" -eq 0 ] && grep -q '^DELIVERED' "$BEATOUT"; then
  ok "since-clamp: a 10-minute-future --since still accepts the real write"
else bad "since-clamp: no DELIVERED line — --since was trusted past now, threshold unsatisfiable"; fi
rm -rf "$W"
}

# --- 5. --since may pull the threshold EARLIER (the post-compaction join) -------
# THE STUB'S CONTROL IS `stub_works`, NOT THE BARE BEAT. The bare beat does sleep, but whether it
# reaches its sleep before a 3s deadline is itself a load bound; the stub's own `sleep 0` through
# the same PATH proves the record channel with no clock in it. The --since beat's empty record
# then means that beat really did not sleep.
C05_since_earlier() {
W="$( bash "$SEED" since-earlier )"
sleep_stub "$W/.stub" fast
beat "$W"
if [ "$RC" -eq 0 ] && grep -q '^WAITING' "$BEATOUT" && ! grep -q '^DELIVERED' "$BEATOUT"; then
  ok "since-earlier: bare call waits — a pre-join file is not proof, and waiting is not a failure"
else bad "since-earlier: rc $RC — expected a WAITING beat with no DELIVERED line"; fi
if stub_works; then ok "since-earlier: CONTROL — the sleep stub records a sleep run through its PATH"
else bad "since-earlier: the sleep stub recorded nothing — 'did not sleep' below would be unmeasured"; fi
: > "$STUB_LOG"
# Quantum 4, not the default 1: an undelivered beat must be ABLE to enter its poll sleep here, or
# the empty record below could not fail. The stub is `fast`, so that failing direction costs a few
# 0.05s sleeps and the passing direction costs nothing.
BW_Q=4; BW_PATH="$STUB_PATH"
beat "$W" --since "$(( $(date +%s) - 60 ))"
BW_Q=""; BW_PATH=""
if [ "$RC" -eq 0 ] && grep -q '^DELIVERED' "$BEATOUT"; then
  ok "since-earlier: --since in the past recovers the early delivery"
else bad "since-earlier: no DELIVERED line — --since could not move the threshold earlier"; fi
# Also proves the fix did not turn every join into a mandatory sleep.
if [ "$(stub_lines)" = "0" ]; then ok "since-earlier: returned without entering its poll sleep"
else bad "since-earlier: entered its poll sleep $(stub_lines) time(s) on an already-satisfied join"; fi
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
#
# THE KNOBS ARE CHOSEN SO THE TWO READINGS DIFFER IN A YES/NO FACT, NOT IN A DURATION. The beat's
# deadline is `now + BUDGET - max(MARGIN, POLL)`, and the loop checks the deadline BEFORE it
# sleeps. With MARGIN 3, a quantum of 3 puts the deadline at `now` exactly, so the beat honouring
# its quantum breaks out of the loop without entering its poll sleep, by construction and at any
# load. A quantum of 60 puts it 57s out, so a beat that read that number enters the sleep. The
# forward case honours 3 against a steering budget of 60; the reverse case honours 60 against
# a steering budget of 3. Each reading the WRONG knob lands on the other side of that line. The
# target is written on the first recorded sleep, so a beat on the sleeping side returns at its
# first wake instead of running its quantum out -- the passing reverse case pays one POLL.
knob_beat() { # <work> <quantum> <steering budget>
  ( cd "$1" && env PATH="$STUB_PATH" AI_DLC_WAIT_BEAT_SECS="$2" AI_DLC_STEERING_BUDGET="$3" \
                   AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=3 \
                   AI_DLC_MAX_WAIT_BEATS=6 \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" deliv.md ) > "$BEATOUT" 2>&1 || true
}
C08_knob_split_forward() {
W="$( bash "$SEED" knob-split-forward )"
sleep_stub "$W/.stub" fast
# The control runs first and its record is cleared: the beat's own record must start empty.
if stub_works; then ok "knob-split-forward: CONTROL — the sleep stub records a sleep run through its PATH"
else bad "knob-split-forward: the sleep stub recorded nothing — 'the beat did not sleep' below would be unmeasured"; fi
: > "$STUB_LOG"
deliver_on_sleep "$W/deliv.md" "$W/.stub/stop"
knob_beat "$W" 3 60
end_writer "$W/.stub/stop"
if grep -q '^BEAT COMPLETE' "$BEATOUT" && [ "$(stub_lines)" = "0" ]; then
  ok "knob-split-forward: quantum 3s honoured (deadline reached before any poll sleep) with STEERING_BUDGET=60 ignored"
else bad "knob-split-forward: $(stub_lines) poll sleep(s) recorded, or no BEAT COMPLETE — the beat is reading AI_DLC_STEERING_BUDGET again"; fi
rm -rf "$W"
}

# Reverse: the steering budget cannot SHORTEN the beat either. Without this arm an
# alias in the other direction (STEERING_BUDGET winning when both are set) still
# passes the forward case whenever the budget happens to be the smaller number.
C09_knob_split_reverse() {
W="$( bash "$SEED" knob-split-reverse )"
sleep_stub "$W/.stub" fast
deliver_on_sleep "$W/deliv.md" "$W/.stub/stop"
knob_beat "$W" 60 3
end_writer "$W/.stub/stop"
if [ "$(stub_lines)" -ge 1 ] && grep -q '^DELIVERED' "$BEATOUT"; then
  ok "knob-split-reverse: quantum 60s honoured (the beat entered its poll sleep) with STEERING_BUDGET=3 ignored"
else bad "knob-split-reverse: $(stub_lines) poll sleep(s) recorded — AI_DLC_STEERING_BUDGET is truncating the beat"; fi
rm -rf "$W"
}

# --- 9. the marker is a LEASE, not the beat's end time ---------------------------
# Stop-hook Check 2b authorizes the lead's yield for as long as `.beat-inflight`
# holds a future epoch. Written ONCE with the beat's end time, a SIGKILLed beat
# (no EXIT trap) leaves that authorization standing for the whole remaining
# quantum with nothing alive to re-invoke the lead — a dead window that grows with
# the quantum, which is exactly what raising it to 600s would have multiplied.
# Re-stamped every poll, the lease expires ~3 polls after the beat dies.
#
# THE BOUND IS AGAINST AN EVENT THE CASE RECORDS, NOT AGAINST "NOW". It once read `LEASE - now
# <= 10`: a slack in seconds, which a late read moves. Now the case stamps KILL_T AFTER the
# beat's whole tree is dead. Stamped before the kill, it left a window -- reap_tree forks pgrep
# per level before any SIGKILL lands -- in which a POLL-1 re-stamp could cross a second boundary
# and write `(KILL_T + 1) + 3`, a false red that grows with load. After the kill, every write the
# subject made strictly precedes the stamp; every lease is `now + 3 x POLL` at its write, and a
# whole-second clock is monotone, so a per-poll lease satisfies `LEASE <= KILL_T + 3 x POLL` at
# ANY load. The END-time defect writes `T0 + QUANTUM - RESERVE`, which is above that bound
# whenever the kill lands earlier than QUANTUM - RESERVE - 3 x POLL after the beat started.
#
# THE ONE STATE WHERE THE TWO MEET IS A REFUSAL, NOT A PASS. A kill that came that late -- the
# box stalled for most of a minute between start and kill -- leaves a bound the END-time lease
# also satisfies, so a green there would be green for the defect too. MS_DISCRIM says whether
# the defect's lease (measured from MS_T0, taken BEFORE the beat started, so it can only
# understate the defect's epoch) lies strictly above the bound; when it does not, the case says
# the run could not discriminate and fails rather than scoring it. MS_Q is 60 so that state needs
# a ~56s stall; the passing path pays only the wait for the first marker.
#
# THE BEAT'S WHOLE TREE IS REAPED, NOT ITS WRAPPER. `kill -9 -$PID` names a process group a
# background job in a non-interactive shell need not lead, and its fallback kills only `$PID`; if
# that is a wrapper rather than the subject, the subject would keep re-stamping after KILL_T and
# this bound would score it as a defect. reap_tree collects the tree top-down and SIGKILLs all of
# it, so no EXIT trap runs and nothing writes after KILL_T.
MS_Q=60; MS_POLL=1; MS_MARGIN=1
run_stale() { # <subject> -> MS_LEASE MS_KILL_T MS_DISCRIM ; leaves W
  local pid i reserve
  W="$( bash "$SEED" marker-goes-stale )"
  MS_T0="$(date +%s)"
  ( cd "$W" && env AI_DLC_WAIT_BEAT_SECS="$MS_Q" AI_DLC_WAIT_POLL_SECS="$MS_POLL" \
                   AI_DLC_WAIT_MARGIN_SECS="$MS_MARGIN" AI_DLC_MAX_WAIT_BEATS=6 \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$1" deliv.md >/dev/null 2>&1 ) & pid=$!
  for i in $(seq 1 3000); do
    [ -s "$W/_bmad-output/.beat-inflight" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.02
  done
  reap_tree "$pid"
  MS_KILL_T="$(date +%s)"
  MS_LEASE="$(marker_of "$W")"
  MS_LEASE="${MS_LEASE%% *}"   # the marker is `<epoch> <pid>`; the lease is the first field
  reserve="$MS_MARGIN"; [ "$MS_POLL" -gt "$reserve" ] && reserve="$MS_POLL"
  MS_DISCRIM=0
  [ $(( MS_T0 + MS_Q - reserve )) -gt $(( MS_KILL_T + 3 * MS_POLL )) ] && MS_DISCRIM=1
}
stale_preconditions() { # <label>
  if [ "$MS_DISCRIM" -eq 1 ]; then
    pre_ok "$1: CONTROL — the kill came early enough that an END-time lease would lie above the per-poll bound"
  else pre_bad "$1: the kill came $(( MS_KILL_T - MS_T0 ))s after the start, so an END-time lease also fits under the bound — this run cannot tell the two apart (refused, not scored)"; fi
}
C10_marker_goes_stale() {
run_stale "$SUBJ"
stale_preconditions "marker-goes-stale"
case "$MS_LEASE" in
  ''|*[!0-9]*) bad "marker-goes-stale: marker absent or non-numeric after SIGKILL — cannot tell a lease from a promise" ;;
  *)
    if [ "$MS_LEASE" -le $(( MS_KILL_T + 3 * MS_POLL )) ]; then
      ok "marker-goes-stale: dead beat's lease ($MS_LEASE) is no later than 3 polls past the kill ($MS_KILL_T), not the rest of the quantum"
    else
      bad "marker-goes-stale: lease $MS_LEASE is past the kill ($MS_KILL_T) + 3 polls — the marker holds the beat's END time, so a crashed beat authorizes a silent stall for the whole quantum"
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
              AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --progress-path "$1" deliv.md ) >/dev/null 2>&1; echo $?; }
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
    pre_ok "$2: CONTROL — one sibling marker, so the seeding shell IS the subject's parent"
  else pre_bad "$2: $n sibling markers — the seeded marker is not the one the subject keyed on, so this case did not run with MAY_SLEEP=0"; fi
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

# ===========================================================================
# CONCURRENT BEATS: THE LEASE, AND THE PER-PROCESS JOIN MEMO (cases 33-45)
# ===========================================================================
# EVERY BEAT HERE RUNS IN ITS OWN PARENT SHELL, AND THAT IS THE HARNESS, NOT TIDINESS. Two
# beats started from one shell share $PPID, so the second sees the first's `.shell-$PPID`
# marker, takes the chained-sibling return, and neither sleeps nor holds a lease -- every
# assertion below would then be about the chained path. `own` gives each beat a fresh `bash -c`
# parent; the trailing `exit $?` stops bash exec-ing the last command, which would hand the
# subject the WRAPPER's parent instead (see `chained_beat` for the measurement). Every runner
# asserts the result through `separate_shells`: one `.shell-*` marker per beat started, and no
# beat printing the sibling NOTE.
own() { bash -c '"$@"; exit $?' _ "$@"; }

# bg_beat <subject> <work> <out> <quantum> <poll> [args...] -> starts one beat in its own
# shell, in the background; sets BG to the pid `wait` takes. The subject's OWN pid is read
# from what it writes (the marker, its `.lease-<pid>`), never from `$!`, which names the
# subshell. SETTLE=2 matters only under --complete and keeps those cases inside a quantum.
# BG_PATH, when set, is the PATH that one beat runs with (the sleep stub's); unset, the fixture's.
BG=""; BG_PATH=""
bg_beat() {
  local subj="$1" w="$2" o="$3" q="$4" p="$5"; shift 5
  ( cd "$w" && own env PATH="${BG_PATH:-$PATH}" AI_DLC_WAIT_BEAT_SECS="$q" AI_DLC_WAIT_POLL_SECS="$p" \
                       AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 \
                       AI_DLC_WAIT_SETTLE_SECS=2 \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$subj" "$@" ) > "$o" 2>&1 &
  BG=$!
}
until_true() { # <tenths> <command...> -- 0 once the command succeeds, 1 on timeout
  local n="$1"; shift
  n=$(( n * 5 ))   # callers count 0.1s ticks; the tick is 0.02s, so the bound in seconds is unchanged
  while [ "$n" -gt 0 ]; do "$@" && return 0; sleep 0.02; n=$((n - 1)); done
  return 1
}
until_event() { # <command...> -- returns once the command succeeds; NO count and NO time cap. A hang
                # here is a hang to read, never a verdict: load can only make it slower.
  while ! "$@"; do sleep 0.02; done
}
now_at_least() { [ "$(date +%s)" -ge "$1" ]; }   # re-reads the clock on every call
marker_of() { # <work> -> the marker's bytes, empty when absent. `read`, not `cat`: a builtin,
              # so a 50ms sampling loop does not fork. The marker carries no newline, so read
              # returns 1 at EOF having assigned the line -- hence the `|| true`.
  local l=""
  IFS= read -r l 2>/dev/null < "$1/_bmad-output/.beat-inflight" || true
  printf '%s' "$l"
}
marker_pid() { local c; c="$(marker_of "$1")"; case "$c" in *' '*) printf '%s' "${c#* }" ;; esac; }
count_glob() { [ -e "$1" ] || { echo 0; return; }; echo "$#"; }   # call as: count_glob <glob>
lease_n() { count_glob "$1"/_bmad-output/.wait-beats/.lease-*; }
leases_are() { [ "$(lease_n "$1")" = "$2" ]; }
fx_key() { printf '%s' "$1" | cksum | tr -d ' \t' | cut -c1-16; }
counter_is() { [ "$(cat "$1/_bmad-output/.wait-beats/$(fx_key "$2")" 2>/dev/null)" = "$3" ]; }
other_lease_pid() { # <work> <pid> -> the registered beat pid that is not <pid>
  local f p
  for f in "$1"/_bmad-output/.wait-beats/.lease-*; do
    [ -e "$f" ] || continue
    p="${f##*/.lease-}"; [ "$p" = "$2" ] || { printf '%s' "$p"; return; }
  done
}
# SIGKILL a backgrounded beat's whole tree, collected top-down before any kill. A bare kill of
# `$!` leaves the subject reparented to init and still sweeping.
reap_tree() {
  local all="$1" frontier="$1" next p
  while [ -n "$frontier" ]; do
    next=""
    for p in $frontier; do next="$next $(pgrep -P "$p" 2>/dev/null | tr '\n' ' ')"; done
    frontier="$(echo $next)"; all="$all $frontier"
  done
  kill -9 $all 2>/dev/null || true
  wait "$1" 2>/dev/null || true
}
# 0 when a `sleep` runs anywhere under the given pid -- the beat has passed every lease write that
# precedes its poll loop. Walks children top-down, as reap_tree does.
# BASENAME, NOT EXACT NAME: `ps -o comm=` reports what the process was exec'd as, so the sleep
# stub's `exec /bin/sleep` reads `/bin/sleep`. Matching `= sleep` alone never saw a stubbed beat
# asleep -- measured: the handoff arm waited out A's whole 600s POLL because neither this nor
# tree_kill_sleep could find A's sleep.
tree_has_sleep() { # <pid>
  local frontier="$1" next p
  while [ -n "$frontier" ]; do
    next=""
    for p in $frontier; do
      case "$(ps -o comm= -p "$p" 2>/dev/null)" in sleep|*/sleep) return 0 ;; esac
      next="$next $(pgrep -P "$p" 2>/dev/null | tr '\n' ' ')"
    done
    frontier="$(echo $next)"
  done
  return 1
}
# SIGTERM every `sleep` under the given pid -- ends a beat's poll sleep early, so it wakes NOW.
# A beat's `sleep` is a foreground child; the subject does not run under `set -e`, so a sleep
# that exits by signal returns to the loop exactly as one that ran out.
tree_kill_sleep() { # <pid>
  local frontier="$1" next p
  while [ -n "$frontier" ]; do
    next=""
    for p in $frontier; do
      case "$(ps -o comm= -p "$p" 2>/dev/null)" in sleep|*/sleep) kill -TERM "$p" 2>/dev/null ;; esac
      next="$next $(pgrep -P "$p" 2>/dev/null | tr '\n' ' ')"
    done
    frontier="$(echo $next)"
  done
  return 0
}
tree_signal() { # <pid> <STOP|CONT> -- every process under pid, collected top-down first
  local all="$1" frontier="$1" next p
  while [ -n "$frontier" ]; do
    next=""
    for p in $frontier; do next="$next $(pgrep -P "$p" 2>/dev/null | tr '\n' ' ')"; done
    frontier="$(echo $next)"; all="$all $frontier"
  done
  kill -"$2" $all 2>/dev/null || true
}
SHELLS_OK=0
separate_shells() { # <work> <beats started> <out>... -> sets SHELLS_OK
  local w="$1" n="$2" f; shift 2
  SHELLS_OK=1
  [ "$(count_glob "$w"/_bmad-output/.wait-beats/.shell-*)" = "$n" ] || SHELLS_OK=0
  for f in "$@"; do grep -q 'a sibling beat already ran' "$f" && SHELLS_OK=0; done
}
say_shells() { # <label>
  if [ "$SHELLS_OK" -eq 1 ]; then pre_ok "$1: CONTROL — each beat ran in its own parent shell (one .shell marker per beat, no sibling NOTE)"
  else pre_bad "$1: beats shared a parent shell or took the chained-sibling return — this case did not test concurrent sleeping beats"; fi
}

# --- the lease handoff --------------------------------------------------------------------
# B starts FIRST so B is the HOLDER: the heir branch in lease_release runs only in the beat that
# holds the marker when it exits, so with A holding, B's exit touches nothing and a subject with
# no handoff passes.
#
# A'S WAKE IS NOT A CLOCK THE READ RACES; IT IS AN EVENT THE HARNESS CAUSES AND THE STUB RECORDS.
# This arm once gave A a quantum of POLL + 2 with POLL 12 and voided the case when the read came
# 12s or more after A started (`HO_READ_EARLY`, a wall bound). Measured at load ~75: B's delivery
# slid past a 6s wake and the trap mutant SURVIVED. The read itself is bracketed by A's freeze, so
# the only way to read late is that A woke and re-stamped BEFORE the freeze. Now:
#   - A runs under the recording `sleep` stub (sleep_stub), with POLL 600 and quantum 2 x POLL:
#     no setup can reach its natural wake, and its deadline is POLL out when the loop checks it.
#   - The control is binary: at the freeze A has recorded EXACTLY ONE poll sleep and that sleep
#     process is still in A's tree. A has entered its loop and has not woken, so every marker
#     write of A's lies before the freeze, and the read after B's exit sees what B's exit left.
#   - After the read A is woken ON PURPOSE: CONT, then its stub `sleep` child is killed. A's
#     `sleep` returns, A re-stamps, sees a.md and delivers, so the C33 controls still hold and the
#     passing path never waits out the long POLL.
# A's lease is 3 x POLL, so the epoch is well clear of `now` at the read.
HO_POLL=600
run_handoff() { # <subject> -> HO_* ; leaves W for the caller
  W="$( bash "$SEED" lease-handoff )"
  local pb pa sp bs_path bs_log
  # B GETS A's CONSTRUCTION, NOT A CLOCK. B once ran POLL 1, so its lease was `now + 3` and a beat
  # stalled for 3s on a loaded box let that lease LAPSE; A's pre-loop write then legitimately took the
  # expired marker (`B=.. A=.. holder=A`). Freezing B cannot repair that, a stopped beat re-stamps
  # nothing. So B is parked the way A is: POLL 600 under its OWN recording sleep stub (a separate dir, so
  # A's record, HO_SLEEPS, still counts only A's sleeps), a lease of 3 x POLL that no load can reach, and
  # A is not started until B's stub has RECORDED B's first poll sleep, which is after both of B's
  # pre-loop lease writes. The order is a file, not a delay. B is woken on purpose below, as A is.
  sleep_stub "$W/.stubB"; bs_path="$STUB_PATH"; bs_log="$STUB_LOG"
  sleep_stub "$W/.stub"
  BG_PATH="$bs_path"; bg_beat "$1" "$W" "$W/b.out" "$(( 2 * HO_POLL ))" "$HO_POLL" b.md; pb=$BG; BG_PATH=""
  HO_B_ASLEEP=0; until_true 600 test -s "$bs_log" && HO_B_ASLEEP=1
  HO_B="$(marker_pid "$W")"
  BG_PATH="$STUB_PATH"; bg_beat "$1" "$W" "$W/a.out" "$(( 2 * HO_POLL ))" "$HO_POLL" a.md; pa=$BG; BG_PATH=""
  until_true 100 leases_are "$W" 2 || true
  # A writes the lease twice before it sleeps: early, and again just before the poll loop. If B
  # exits between the two, A's second write takes the free marker and EVERY subject -- the trap
  # mutant included -- leaves a marker naming A. Measured: 4 of 4 trap-mutant survivors at load
  # ~60 passed every other control. So B's target lands only once A is in its `sleep`.
  HO_A_ASLEEP=0; until_true 150 tree_has_sleep "$pa" && HO_A_ASLEEP=1
  HO_A="$(other_lease_pid "$W" "$HO_B")"
  HO_HOLDER0="$(marker_pid "$W")"
  # A IS FROZEN from before B's target lands until after the read, so no write of A's can fall
  # between B's exit and the read: the marker read is exactly what B's exit left, whatever the
  # load. `kill -0` still answers for a stopped process, which is what lease_release asks.
  tree_signal "$pa" STOP
  # A re-stamps (and so re-takes) the marker when its first sleep returns. The control: at the
  # freeze A has recorded EXACTLY ONE sleep and that sleep is still running in A's tree -- A is
  # inside its first poll sleep and has not woken. Anything else voids the case: measured at load
  # ~75 under the old clock-bounded shape, A woke first and the trap mutant SURVIVED.
  HO_SLEEPS="$(stub_lines)"
  HO_UNWOKEN=0; [ "$HO_SLEEPS" = "1" ] && tree_has_sleep "$pa" && HO_UNWOKEN=1
  printf 'the answer B was waiting for\n' > "$W/b.md"
  # WAKE B ON PURPOSE: end its stub sleep. B's loop re-stamps, finds b.md and delivers, so its exit (the
  # event under test) happens now and the passing path never waits out B's long POLL. A is still frozen.
  tree_kill_sleep "$pb"
  until_true 1200 eval '! kill -0 "$pb" 2>/dev/null' || reap_tree "$pb"
  wait "$pb" 2>/dev/null || true
  HO_AFTER="$(marker_of "$W")"
  HO_NOW="$(date +%s)"
  HO_A_ALIVE=0; [ -n "$HO_A" ] && kill -0 "$HO_A" 2>/dev/null && HO_A_ALIVE=1
  printf 'the answer A was waiting for\n' > "$W/a.md"
  # WAKE A ON PURPOSE: resume it, then end its stub sleep. A's loop re-stamps, finds a.md and
  # delivers, so the passing path never waits out POLL 600.
  tree_signal "$pa" CONT
  tree_kill_sleep "$pa"
  # A WAKE THAT DID NOT HAPPEN IS A RED, NOT A 600s STALL. A woken beat delivers in well under a
  # second; if it is still running after this bound its tree is reaped, a.out carries no
  # DELIVERED line, and the C33 control below fails loudly. The bound decides no verdict -- it
  # only stops a broken wake from holding the pool for ten minutes.
  until_true 300 eval '! kill -0 "$pa" 2>/dev/null' || reap_tree "$pa"
  wait "$pa" 2>/dev/null || true
  HO_GONE=1; [ -e "$W/_bmad-output/.beat-inflight" ] && HO_GONE=0
  separate_shells "$W" 2 "$W/a.out" "$W/b.out"
}
handoff_preconditions() { # <label> -- the harness facts both the case and its mutants rest on
  say_shells "$1"
  if [ "$HO_B_ASLEEP" -eq 1 ] && [ -n "$HO_B" ] && [ "$HO_HOLDER0" = "$HO_B" ] && [ -n "$HO_A" ] && [ "$HO_A" != "$HO_B" ]; then
    pre_ok "$1: CONTROL — B held the marker and A was registered before B's target landed"
  else pre_bad "$1: B=$HO_B A=$HO_A holder=$HO_HOLDER0 — B was not the holder, so its exit cannot exercise the handoff"; fi
  if [ "$HO_A_ALIVE" -eq 1 ]; then pre_ok "$1: CONTROL — A was still asleep when the marker was read"
  else pre_bad "$1: A was not alive at the read; the marker's state then says nothing about a live sibling"; fi
  if [ "$HO_A_ASLEEP" -eq 1 ]; then pre_ok "$1: CONTROL — A was in its sleep, past both pre-loop lease writes, before B's target landed"
  else pre_bad "$1: A never reached its sleep before B's target landed — A's pre-loop lease write could take the marker B freed"; fi
  if [ "$HO_UNWOKEN" -eq 1 ]; then pre_ok "$1: CONTROL — at the freeze A had entered exactly one poll sleep and was still in it, so no wake of A's re-took the marker before the read"
  else pre_bad "$1: at the freeze A had recorded $HO_SLEEPS poll sleep(s), or its sleep had already returned — A may have re-stamped before the read, so this read cannot see B's exit (void)"; fi
}
C33_lease_handoff() {
run_handoff "$SUBJ"
handoff_preconditions "lease-handoff"
if grep -q '^DELIVERED b.md' "$W/b.out"; then ok "lease-handoff: B delivered and exited"
else bad "lease-handoff: B did not deliver b.md — the exit under test never happened"; fi
ep="${HO_AFTER%% *}"; case "$ep" in ''|*[!0-9]*) ep=0 ;; esac
ap=""; case "$HO_AFTER" in *' '*) ap="${HO_AFTER#* }" ;; esac
if [ -n "$HO_A" ] && [ "$ap" = "$HO_A" ] && [ "$ep" -gt "$HO_NOW" ]; then
  ok "lease-handoff: after B exits the marker names A with a live lease — the sleeping beat keeps the yield"
else bad "lease-handoff: marker '$HO_AFTER' after B exited (A=$HO_A, now=$HO_NOW) — the first beat out took the lease from a beat still asleep"; fi
if grep -q '^DELIVERED a.md' "$W/a.out" && [ "$HO_GONE" -eq 1 ]; then
  ok "lease-handoff: CONTROL — A delivered, and the marker is gone once the last beat exits"
else bad "lease-handoff: the marker survived the last beat (or A never delivered) — a dead join would authorize a silent stall"; fi
rm -rf "$W"
}
# --- no clobber ---------------------------------------------------------------------------
# An after-exit byte comparison cannot see a beat that takes a live holder's marker: on exit it
# holds it, hands it to the heir, and writes A's own epoch and pid back -- byte-identical. So the
# marker is SAMPLED while the second beat runs, and that beat is given 30 delivered targets so
# its sweep is wide enough to sample.
#
# A'S WINDOW OUTLASTS THE PROBE BY CONSTRUCTION, NOT BY A QUANTUM. A was once the single-wake
# shape from the handoff arm (POLL 8, quantum 10): a ~10s life against a setup plus a 30-target
# sweep that both scale with the box's load. Under a loaded pool A exited first -- measured on a
# consumer push: "delivered 30 of 30, A alive=0 -- the window under test never ran", beside a
# false "clobbered a live lease" whose two markers carried A's OWN pid and differed only by
# epoch: A's own re-stamp, at its +8s wake, inside a window that had run late. So now:
#   - A is FROZEN (SIGSTOP, its whole tree) once it is in its poll `sleep` -- past both pre-loop
#     lease writes -- and stays frozen until it is reaped. A stopped process writes nothing, so
#     A's own re-stamp cannot land in the window at ANY load, and `kill -0` still answers for it,
#     which is all the second beat's `lease_holder_dead` asks of A's pid.
#   - A's POLL is 600, so its registration (`.lease-<A>`, `now + 3 x POLL`) stays live for half
#     an hour: the second beat cannot LEGITIMATELY take a marker whose holder's lease ran out,
#     which a long sweep against POLL 8's 24s lease could have let it do on a correct subject.
#   - Both are CONTROLS read at the end of the window: A is still stopped (`ps` state T) and its
#     registration is still in the future. Either one false voids the case rather than scoring
#     it. reap_tree SIGKILLs A anyway, so the passing path never pays for the long POLL.
#   - A's quantum is 2 x POLL, so its deadline (`now + quantum - POLL`) is POLL seconds out when
#     its loop first checks it. At quantum POLL + 2 a two-second stall between computing the
#     deadline and checking it would send A out of the loop without ever sleeping -- a load
#     bound reintroduced one level down.
NC_POLL=600
run_noclobber() { # <subject> -> NC_* ; leaves W
  W="$( bash "$SEED" lease-noclobber )"
  local pa pi i cur args le
  args=""
  for i in $(seq 1 30); do printf 'delivered\n' > "$W/d$i.md"; args="$args d$i.md"; done
  bg_beat "$1" "$W" "$W/a.out" "$(( 2 * NC_POLL ))" "$NC_POLL" a.md; pa=$BG
  # A ASLEEP, not merely started: A re-stamps once more after charging its beat and before the
  # sleep, and a baseline read before that re-stamp would score A's own write as a clobber. The
  # sleep child is the proof A is past every pre-loop write; then A is frozen where it stands.
  NC_A_ASLEEP=0; until_true 600 tree_has_sleep "$pa" && NC_A_ASLEEP=1
  tree_signal "$pa" STOP
  NC_M0="$(marker_of "$W")"
  NC_A="$(marker_pid "$W")"
  ( cd "$W" && AI_DLC_PROJECT_ROOT="$PWD" bash "$1" --status other.md ) > "$W/st.out" 2>&1
  NC_STATUS="$(marker_of "$W")"
  # $args is a word list built above with no spaces inside a word, so it is left unquoted.
  bg_beat "$1" "$W" "$W/i.out" 4 1 --since "$(( $(date +%s) - 60 ))" $args; pi=$BG
  # NC_SEEN: the first sample differing from A's baseline. NC_FOREIGN: the first naming a pid
  # other than A's -- the clobber itself. The LAST differing sample would be the wrong one to
  # keep: a clobbering beat hands the marker back to A at exit, with A's latest registration.
  NC_SEEN=""; NC_FOREIGN=""
  while kill -0 "$pi" 2>/dev/null; do
    cur="$(marker_of "$W")"
    if [ "$cur" != "$NC_M0" ]; then
      [ -n "$NC_SEEN" ] || NC_SEEN="${cur:-<absent>}"
      case "$cur" in *" $NC_A") : ;; *) [ -n "$NC_FOREIGN" ] || NC_FOREIGN="${cur:-<absent>}" ;; esac
    fi
    sleep 0.05
  done
  wait "$pi" 2>/dev/null || true
  NC_AFTER="$(marker_of "$W")"
  NC_DELIV="$(grep -c '^DELIVERED d' "$W/i.out" || true)"
  NC_A_ALIVE=0; [ -n "$NC_A" ] && kill -0 "$NC_A" 2>/dev/null && NC_A_ALIVE=1
  NC_A_STOPPED=0
  case "$NC_A" in ''|*[!0-9]*) : ;; *) case "$(ps -o stat= -p "$NC_A" 2>/dev/null)" in *T*) NC_A_STOPPED=1 ;; esac ;; esac
  NC_A_LEASED=0; le=""
  [ -n "$NC_A" ] && le="$(cat "$W/_bmad-output/.wait-beats/.lease-$NC_A" 2>/dev/null || echo '')"
  case "$le" in ''|*[!0-9]*) : ;; *) [ "$le" -gt "$(date +%s)" ] && NC_A_LEASED=1 ;; esac
  reap_tree "$pa"
  separate_shells "$W" 2 "$W/a.out" "$W/i.out"
}
noclobber_preconditions() { # <label>
  say_shells "$1"
  if [ "$NC_DELIV" = "30" ] && [ "$NC_A_ALIVE" -eq 1 ]; then
    pre_ok "$1: CONTROL — the second beat delivered all 30 targets while A ($NC_A) stayed alive"
  else pre_bad "$1: delivered $NC_DELIV of 30, A alive=$NC_A_ALIVE — the window under test never ran"; fi
  if [ "$NC_A_ASLEEP" -eq 1 ] && [ "$NC_A_STOPPED" -eq 1 ]; then
    pre_ok "$1: CONTROL — A was in its poll sleep when frozen and still frozen at the window's end, so no marker write in the window is A's"
  else pre_bad "$1: A asleep=$NC_A_ASLEEP stopped=$NC_A_STOPPED — A could write the marker inside the window, so a change there is not attributable to the second beat"; fi
  if [ "$NC_A_LEASED" -eq 1 ]; then
    pre_ok "$1: CONTROL — A's registration was still in the future at the window's end; no beat could take the marker legitimately"
  else pre_bad "$1: A's .lease-$NC_A was expired or absent at the window's end — a correct beat may take a dead holder's marker, so a change there is not a clobber"; fi
}
# What a sampled change MEANS, once the controls above hold. A is frozen, so A wrote nothing in
# the window: a marker naming another pid is the second beat holding it, and a marker naming A's
# own pid with a different epoch is the second beat's exit handing A's registration BACK -- it
# took and returned the lease between two samples. Both are the clobber; they are worded apart so
# a red says which, and so A's own re-stamp (impossible while frozen, and voided by the control
# if A was not frozen) can never again be read as one.
nc_clobber_reason() {
  if [ -n "$NC_FOREIGN" ]; then
    printf "the marker read '%s' mid-beat against A's '%s' — a second beat took a live holder's lease" "$NC_FOREIGN" "$NC_M0"
  else
    printf "the marker read '%s' mid-beat against A's '%s' — rewritten naming A's own pid with a new epoch while A was frozen, so another beat took the lease and handed it back between samples" "$NC_SEEN" "$NC_M0"
  fi
}
C36_lease_noclobber() {
run_noclobber "$SUBJ"
noclobber_preconditions "lease-noclobber"
if grep -q '^STATUS --' "$W/st.out" && [ "$NC_STATUS" = "$NC_M0" ]; then
  ok "lease-noclobber: --status on another path leaves A's marker byte-identical"
else bad "lease-noclobber: --status rewrote the marker ('$NC_M0' -> '$NC_STATUS') or did not run"; fi
if [ -z "$NC_SEEN" ]; then
  ok "lease-noclobber: an instantaneous beat never takes a live holder's marker, sampled throughout"
else bad "lease-noclobber: $(nc_clobber_reason)"; fi
if [ "$NC_AFTER" = "$NC_M0" ]; then ok "lease-noclobber: CONTROL — A's marker is unchanged after that beat exits"
else bad "lease-noclobber: marker '$NC_AFTER' after the instant beat, expected A's '$NC_M0'"; fi
rm -rf "$W"
}
# --- the lease is written before the sweep --------------------------------------------------
# The subject writes the marker strictly before it writes any `.since`, and never deletes it
# mid-run, so the predicate is deterministic in both directions: AT THE FIRST OBSERVATION of a
# sidecar, the marker exists. The sidecar count at that instant must be below N -- an
# observation taken after the sweep would see a late marker too, and the fix and the mutant
# would then score alike. The beat is reaped once observed: run out, a large wave costs a
# multi-second sweep plus a report that re-forks per target (measured at load ~60: 200 targets
# swept in 9.3s, the marker at 0.08s, the first sidecar at 0.12s).
EARLY_N=150
run_early() { # <subject> -> EA_* ; leaves W
  W="$( bash "$SEED" lease-early )"
  local p i args d
  args=""
  for i in $(seq 1 "$EARLY_N"); do args="$args t$i.md"; done
  bg_beat "$1" "$W" "$W/e.out" 30 1 $args; p=$BG
  d="$W/_bmad-output/.wait-beats"
  EA_SEEN=0; EA_MARK=0; EA_CNT=0
  for i in $(seq 1 600); do
    EA_CNT="$(count_glob "$d"/*.since)"
    if [ "$EA_CNT" -gt 0 ]; then
      EA_SEEN=1; [ -e "$W/_bmad-output/.beat-inflight" ] && EA_MARK=1
      break
    fi
    kill -0 "$p" 2>/dev/null || break
    sleep 0.02
  done
  reap_tree "$p"
}
early_preconditions() { # <label>
  if [ "$EA_SEEN" -eq 1 ] && [ "$EA_CNT" -lt "$EARLY_N" ]; then
    pre_ok "$1: CONTROL — the first sidecar was observed mid-sweep ($EA_CNT of $EARLY_N)"
  else pre_bad "$1: observed=$EA_SEEN at $EA_CNT of $EARLY_N sidecars — the observation was not inside the sweep"; fi
}
C38_lease_early() {
run_early "$SUBJ"
early_preconditions "lease-early"
if [ "$EA_MARK" -eq 1 ]; then ok "lease-early: .beat-inflight exists before the sweep writes its first sidecar"
else bad "lease-early: no marker when the first sidecar appeared — a large wave leaves the hook seeing no beat while it sweeps"; fi
rm -rf "$W"
}
# --- two beats, one path --------------------------------------------------------------------
# Both armed over a seat file before it exists, each from its own shell. The memo matters only
# when the second beat's NEXT `.since` read comes AFTER the first beat delivered and deleted it;
# if both see the seal inside one poll, both deliver before either deletes it and a beat with no
# memo delivers too.
# A SLEEP COULD NOT ORDER THAT. The beats used to start 1.5s apart -- half a POLL out of phase --
# but a poll's wake-up is the scheduler's, not the clock's: under load the two beats' checks drift
# into one window, both delivered, and no-join-memo survived on a loaded run while the subject was
# unchanged.
# THE SENTINEL ORDERS IT. The second beat is frozen (SIGSTOP on its whole tree) while a `sleep`
# runs under it -- its poll sleep, a foreground child, so the beat is between two checks and not
# holding an epoch it read before the seal existed. The seal is then written, the first beat runs
# to its exit, and only once its output says DELIVERED and `.since` is gone is the second beat
# continued. Its next check is therefore after the deletion, every run, whatever the load; it must
# still deliver from its memoised epoch. TB_ORDERED records that the order was imposed, so a
# forcing that silently failed cannot read as a kill.
counter_or_gone() { counter_is "$1" "$2" "$3" || ! kill -0 "$4" 2>/dev/null || ! kill -0 "$5" 2>/dev/null; }   # <work> <file> <n> <pid> <pid>
sleep_or_gone() { tree_has_sleep "$1" || ! kill -0 "$1" 2>/dev/null; }   # <pid>
beat2_resolved() { ! kill -0 "$1" 2>/dev/null || [ -e "$2" ]; }   # <pid> <since file>
run_two_beats() { # <subject> -> TB_* ; leaves W
  W="$( bash "$SEED" two-beats-one-path )"
  local p1 p2 mt
  # BEAT 1 CANNOT EXPIRE BEFORE THE SEAL EITHER. Its quantum is 600s, the same subject parameter as
  # beat 2's below, so the seal wait further down can take as long as load makes it and beat 1 is
  # still inside its quantum when the seal lands; it exits by DELIVERING, not by its clock.
  bg_beat "$1" "$W" "$W/1.out" 600 1 --complete x.md; p1=$BG
  # BEAT 2 CANNOT EXPIRE WHILE FROZEN. Its quantum is 600s against a POLL of 1, so no freeze this
  # harness can hold uses it up (at 12s a long freeze under load spent it: beat 2 woke past its
  # deadline, exited WAITING, and the subject was blamed for a beat it never dropped). It wakes on its
  # own 1s poll once continued, so the passing path stays fast and nothing is killed or stubbed.
  bg_beat "$1" "$W" "$W/2.out" 600 1 --complete x.md; p2=$BG
  # Both past the sweep: each sleeping beat charges the one shared counter.
  # Or either beat is already gone (a mutant can end one before the sweep): then the counter never
  # reaches 2, and what follows scores the case void on TB_ORDERED.
  until_event counter_or_gone "$W" x.md 2 "$p1" "$p2"
  # Freeze beat 2 inside its poll sleep. A sleep still present AFTER the stop proves the beat was
  # parked in it, not mid-check; otherwise continue it and try again at its next sleep. This loop
  # decides no verdict: TB_ORDERED below is what a void case scores on. It retries on the EVENT (beat 2
  # parked in a poll sleep, which recurs at every poll) with no count; it ends only when the freeze
  # holds or beat 2 is gone, and a gone beat leaves TB_FROZEN=0, a void case.
  TB_FROZEN=0
  while [ "$TB_FROZEN" -eq 0 ] && kill -0 "$p2" 2>/dev/null; do
    until_event sleep_or_gone "$p2"
    tree_signal "$p2" STOP
    if tree_has_sleep "$p2"; then TB_FROZEN=1; else tree_signal "$p2" CONT; fi
  done
  printf 'a finding\nseat-complete: s 1 findings=1\n' > "$W/x.md"
  wait "$p1" 2>/dev/null || true
  # `is_delivered` compares whole seconds with `>=`, so a memo-less beat continued inside the
  # seal's own second would re-arm at that second and accept the file on that alone. Continue
  # only once the clock has left it, and make that part of the control.
  mt="$(fx_mtime "$W/x.md")"
  until_event now_at_least "$(( mt + 1 ))"
  # THE PROPERTY TB_N NEEDS: beat 2 is ALIVE and STOPPED in a sleep (its quantum unspent, its next
  # check still ahead of it) when beat 1 has delivered and deleted .since. A beat that had expired
  # or exited reads here as a void case (rc 2), never as a kill or a failure.
  TB_ALIVE=0; kill -0 "$p2" 2>/dev/null && case "$(ps -o stat= -p "$p2" 2>/dev/null)" in *T*) TB_ALIVE=1 ;; esac
  TB_ORDERED=0
  [ "$TB_FROZEN" -eq 1 ] && [ "$TB_ALIVE" -eq 1 ] && grep -q '^DELIVERED x.md' "$W/1.out" \
    && [ ! -e "$W/_bmad-output/.wait-beats/$(fx_key x.md).since" ] \
    && now_at_least "$(( mt + 1 ))" && TB_ORDERED=1
  tree_signal "$p2" CONT
  # Beat 2 now resolves by an EVENT, never a clock: it exits (delivered, from its memo), or it
  # re-creates .since after the seal -- the re-arm a memo-less beat performs, after which it can never
  # deliver and would otherwise poll out its 600s quantum. The wait carries no count and no time cap
  # because it always terminates: beat 2 runs with a 600s quantum and exits on delivery, on re-arm or on
  # expiry, so one of the two events beat2_resolved tests is certain to occur and no load can void it.
  until_event beat2_resolved "$p2" "$W/_bmad-output/.wait-beats/$(fx_key x.md).since"
  reap_tree "$p2"
  wait "$p2" 2>/dev/null || true
  TB_N=0
  grep -q '^DELIVERED x.md' "$W/1.out" && TB_N=$((TB_N + 1))
  grep -q '^DELIVERED x.md' "$W/2.out" && TB_N=$((TB_N + 1))
  separate_shells "$W" 2 "$W/1.out" "$W/2.out"
}
say_ordered() { # <label>
  if [ "$TB_ORDERED" -eq 1 ]; then pre_ok "$1: CONTROL — beat 2 was alive and frozen in its poll sleep, quantum unspent, until beat 1 delivered, .since was gone and the seal's second had passed"
  else pre_bad "$1: the order was not imposed (beat 2 not alive and frozen in a sleep, beat 1 did not deliver, .since survived, or the clock never left the seal's second) — this case did not test the memo"; fi
}
C40_two_beats_one_path() {
run_two_beats "$SUBJ"
say_shells "two-beats-one-path"
say_ordered "two-beats-one-path"
if [ "$TB_N" -eq 2 ]; then ok "two-beats-one-path: both beats deliver one sealed file"
else bad "two-beats-one-path: $TB_N of 2 beats delivered — the second re-armed after the first deleted the shared .since"; fi
rm -rf "$W"
}
# --- ...and a LATER beat still reads a delivered file as pre-existing (Rule 28) -------------
# The memo lives in one process and never re-creates a sidecar, so a NEW beat without --since
# arms at `now` and does not accept the file. It is armed two whole seconds after the write:
# `is_delivered` compares whole seconds with `>=`, so a beat armed in the write's own second
# would accept it on that alone.
run_memo_single() { # <subject> -> MS_* ; leaves W
  W="$( bash "$SEED" memo-single )"
  local p mt
  bg_beat "$1" "$W" "$W/1.out" 6 1 x.md; p=$BG
  until_true 100 counter_is "$W" x.md 1 || true   # past the sweep, so it delivers mid-beat
  printf 'the answer\n' > "$W/x.md"
  wait "$p" 2>/dev/null || true
  mt="$(fx_mtime "$W/x.md")"
  until_true 40 now_at_least "$(( mt + 2 ))" || true
  ( cd "$W" && own env AI_DLC_WAIT_BEAT_SECS=3 AI_DLC_WAIT_POLL_SECS=1 \
                       AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 \
      AI_DLC_PROJECT_ROOT="$PWD" bash "$1" x.md ) > "$W/2.out" 2>&1
  MS_RC=$?
  separate_shells "$W" 2 "$W/1.out" "$W/2.out"
}
C42_memo_single() {
run_memo_single "$SUBJ"
say_shells "memo-single"
if grep -q '^DELIVERED x.md' "$W/1.out"; then ok "memo-single: CONTROL — the first beat delivered x.md mid-beat"
else bad "memo-single: the first beat did not deliver; the later beat is not reading a delivered file"; fi
if [ "$MS_RC" -eq 0 ] && ! grep -q '^DELIVERED' "$W/2.out" && grep -q 'already had content when this join armed' "$W/2.out"; then
  ok "memo-single: a later beat without --since reads the delivered file as pre-existing, as Rule 28 documents"
else bad "memo-single: rc $MS_RC — a later beat accepted a file delivered to an earlier join, or gave no NOTE"; fi
rm -rf "$W"
}
# --- a live pre-upgrade lease is left alone -------------------------------------------------
run_bare_epoch() { # <subject> -> BE_* ; leaves W
  W="$( bash "$SEED" bare-epoch )"
  local p cur
  BE_M0="$(marker_of "$W")"
  bg_beat "$1" "$W" "$W/o.out" 4 1 x.md; p=$BG
  BE_SEEN=""
  while kill -0 "$p" 2>/dev/null; do
    cur="$(marker_of "$W")"
    [ "$cur" = "$BE_M0" ] || BE_SEEN="${cur:-<absent>}"
    sleep 0.02
  done
  wait "$p"; BE_RC=$?
  BE_AFTER="$(marker_of "$W")"
  separate_shells "$W" 1 "$W/o.out"
}
C44_bare_epoch() {
run_bare_epoch "$SUBJ"
say_shells "bare-epoch"
case "$BE_M0" in
  ''|*' '*|*[!0-9]*) bad "bare-epoch: seeded marker '$BE_M0' is not a bare epoch — the case cannot test a pre-upgrade lease" ;;
  *) ok "bare-epoch: CONTROL — the seeded marker is a bare future epoch" ;;
esac
if [ -z "$BE_SEEN" ] && [ "$BE_AFTER" = "$BE_M0" ]; then
  ok "bare-epoch: a live pid-less lease is never taken, during the beat or at its exit"
else bad "bare-epoch: marker went to '${BE_SEEN:-$BE_AFTER}' — a new beat took a live pre-upgrade lease that beat will delete on its own exit"; fi
if [ "$BE_RC" -eq 0 ] && grep -q '^WAITING' "$W/o.out"; then ok "bare-epoch: the beat still ran to a normal WAITING exit"
else bad "bare-epoch: rc $BE_RC and no WAITING line — the beat did not run normally beside an old lease"; fi
rm -rf "$W"
}
# --- 22. every exit code the beat can return is named in Rule 29's exit list ---
# The lead decides what to do from Rule 29's list, not from the script. A code the script returns
# and the list does not name is read by its nearest neighbour: a refused call (64) was read as
# NON-DELIVERY (1), and a live teammate re-dispatched. Both sides are DERIVED: the script's codes
# from its own `exit N` lines and the literal values of the RC it ends on; the list's from its
# `    exit N --` lines. Self-probe first, both directions, on seeded text.
exit_codes_of() {  # $1 = a shell script -> its distinct numeric exit codes, one per line
  awk '
    /^[[:space:]]*#/ { next }
    { l = $0
      while (match(l, /(^|[^A-Za-z_`-])exit [0-9]+/)) {
        s = substr(l, RSTART, RLENGTH); sub(/.*exit /, "", s); seen[s] = 1; l = substr(l, RSTART + RLENGTH) }
      l = $0; if (l ~ /exit "\$RC"/) userc = 1
      while (match(l, /(^|[^A-Za-z_])RC=[0-9]+/)) {
        s = substr(l, RSTART, RLENGTH); sub(/.*RC=/, "", s); rcv[s] = 1; l = substr(l, RSTART + RLENGTH) } }
    END { if (userc) for (k in rcv) seen[k] = 1; for (k in seen) print k }' "$1" | sort -n
}
listed_codes_of() {  # $1 = a rule body -> the codes its beat exit list names
  awk '/^    exit [0-9]+ --/ { print $2 }' "$1" | sort -n
}
C46_exit_codes_named() {
R29="$(pick "$HERE/../../skills/ai-dlc/rule-bodies/rule-29.md" \
            "$HERE/../../../.claude/skills/ai-dlc/rule-bodies/rule-29.md")"
if [ -z "$R29" ]; then bad "exit-list: rule-29.md not found beside this fixture in either layout — nothing was compared"; return; fi
P="$(mktemp -d)"
printf '#!/bin/bash\n# exit 7 in a comment\n[ -n "$x" ] || exit 64\nRC=0\nfoo && RC=1\necho "exit code" ; exit 2\nexit "$RC"\n' > "$P/s.sh"
got="$(exit_codes_of "$P/s.sh" | tr '\n' ' ')"
if [ "$got" = "0 1 2 64 " ]; then ok "exit-list self-probe: a seeded script yields 0 1 2 64 (an RC value counted, a commented exit 7 and the word 'exit code' not)"
else bad "exit-list self-probe: derived '$got' from the seeded script, expected '0 1 2 64 ' — the grammar cannot be trusted on the real script"; fi
printf '    exit 0 -- A\n    exit 1 -- B\n  exit 9 -- not the list indent\n' > "$P/r.md"
got="$(listed_codes_of "$P/r.md" | tr '\n' ' ')"
if [ "$got" = "0 1 " ]; then ok "exit-list self-probe: a seeded list yields 0 1 (a mis-indented exit 9 is not a list line)"
else bad "exit-list self-probe: derived '$got' from the seeded list, expected '0 1 '"; fi
rm -rf "$P"
codes="$(exit_codes_of "$SUBJ")"; listed="$(listed_codes_of "$R29")"
n_c="$(printf '%s\n' "$codes" | grep -c .)" || n_c=0
n_l="$(printf '%s\n' "$listed" | grep -c .)" || n_l=0
if [ "$n_c" -lt 2 ] || [ "$n_l" -lt 2 ]; then
  bad "exit-list: derived $n_c code(s) from the script and $n_l from rule-29 — one side read nothing, so agreement would be vacuous"; return
fi
missing=""
for c in $codes; do grep -qx "$c" <<<"$listed" || missing="$missing $c"; done
if [ -z "$missing" ]; then ok "exit-list: every code the beat can return ($(printf '%s' "$codes" | tr '\n' ' ')) is named in rule-29's exit list"
else bad "exit-list: the beat can exit with$missing, which rule-29's exit list does not name — a lead reads an unnamed code as its nearest neighbour"; fi
# Printed only after the comparison decided on rule-29's content, so it cannot vouch for a read that never happened.
echo "HERMETIC-CONSUMED $(cd "$(dirname "$R29")" && pwd)/$(basename "$R29")"
}

# --- 23. the line the repair brief copies from is a line the beat EMITS ---
# `_gate-procedures.md` tells the lead to copy every `REVISED-AFTER-MARKER <n> <path> --` line the
# `--complete --status` call prints into the remediator brief as `revised-seats:`. A rename of the
# token in the subject would leave the prose naming a line nothing prints. Bound to the EMISSION
# site (an `echo` of the token), not to a comment that mentions it. Self-probe first, both ways.
emits_revised() {  # $1 = a shell script -> 0 when an uncommented echo prints the token
  awk '/^[[:space:]]*#/ { next } /echo "REVISED-AFTER-MARKER \$\{[a-z_]+\} / { hit = 1 } END { exit !hit }' "$1"
}
C47_revised_token_emitted() {
P="$(mktemp -d)"
printf '#!/bin/bash\n# echo "REVISED-AFTER-MARKER ${n_} x"\ntrue\n' > "$P/comment.sh"
printf '#!/bin/bash\necho "REVISED-AFTER-MARKER ${n_} $1 -- changed"\n' > "$P/emit.sh"
if emits_revised "$P/emit.sh" && ! emits_revised "$P/comment.sh"; then ok "revised-token self-probe: an echo of the token matches, a commented mention does not"
else bad "revised-token self-probe: the emission grammar cannot tell an echo from a comment — it cannot be trusted on the real script"; fi
rm -rf "$P"
if emits_revised "$SUBJ"; then ok "revised-token: the beat echoes REVISED-AFTER-MARKER <n> <path> -- , the line the repair brief's revised-seats: is copied from"
else bad "revised-token: the beat no longer echoes REVISED-AFTER-MARKER <n> — _gate-procedures.md still tells the lead to copy that line"; fi
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
  # An optional third word names the SUBJECT this one arm runs against: a mutant copy, or the unmutated
  # copy. Absent, the arm runs on the real subject. Every arm reads $SUBJ, so one arm and one subject are one cell.
  PRE_FILE="${4:-}"
  if [ -n "${3:-}" ] && [ "${3:-}" != "-" ]; then
    [ -f "$3" ] || { echo "FIXTURE ERROR: --run-one subject '$3' is not a file" >&2; exit 2; }
    SUBJ="$3"
  fi
  setup_tmp
  echo "wait-stale-deliverable:"   >/dev/null   # the header belongs to the parent, not here
  "$FN"
  [ "$pre_fails" -eq 0 ] || exit 2
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

# THE CASE LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order, with a zero
# guard. A hand-written list would be the defect this fixture's own subject is about: a case
# dropped from it runs nothing, prints nothing, and 20 greens read exactly like 21.
MATRIX=0
case "${1:-}" in
  "") ;;
  --matrix) MATRIX=1 ;;
  *) echo "FIXTURE ERROR: unknown argument '${1:-}' (usage: run.sh [--matrix])" >&2; exit 2 ;;
esac
NAMES="$(grep -oE '^C[0-9]{2}_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
if [ "$N_LISTED" -lt 10 ]; then
  echo "FIXTURE ERROR: derived $N_LISTED case(s) from this file — the C<nn>_ naming grammar moved" >&2
  exit 2
fi
# C31 re-launches C23 from / and takes no subject, so no mutant can reach it: a base arm only.
ARMS="$(printf '%s\n' "$NAMES" | grep -v '^C31_')"
N_ARMS="$(printf '%s\n' "$ARMS" | grep -c . || true)"
# A here-string read, never a pipe into grep -q: has_arm <name> is 0 when <name> is one of the arms.
has_arm() { grep -qx "$1" <<<"$ARMS"; }

MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
MX_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/matrix.sh"
[ -f "$MUT_LIB" ] && [ -f "$MX_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh or lib/matrix.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
. "$MX_LIB"

echo "wait-stale-deliverable:"
echo "HERMETIC-CONSUMED $(cd "$(dirname "$SUBJ")" && pwd)/$(basename "$SUBJ")"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"

OUT="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$OUT"' EXIT
SELF="$HERE/$(basename "$0")"
MUTDIR="$OUT/mutants"
mkdir "$MUTDIR" || { echo "FIXTURE ERROR: cannot create the mutant dir" >&2; exit 2; }

# THE MUTANT TABLE IS THIS FILE'S OWN HEADER, read back: one `# MUTANT-MATRIX <m> decides=<arm>
# twins=<arm>` line per mutant. The driver and the header cannot disagree because they are one text.
grep -E '^# MUTANT-MATRIX [A-Za-z0-9_-]+ decides=[A-Za-z0-9_]+ twins=[A-Za-z0-9_]+$' "$0" \
  | sed -e 's/^# MUTANT-MATRIX //' -e 's/ decides=/ /' -e 's/ twins=/ /' > "$OUT/table"
N_MUT="$(grep -c . "$OUT/table" || true)"
if [ "$N_MUT" -lt 10 ]; then echo "FIXTURE ERROR: read only $N_MUT mutant row(s) from the header" >&2; exit 2; fi
while read -r m d t; do
  has_arm "$d" && has_arm "$t" || { echo "FIXTURE ERROR: header row '$m' names an arm that does not exist ($d / $t)" >&2; exit 2; }
  [ "$d" != "$t" ] || { echo "FIXTURE ERROR: header row '$m' has twin equal to deciding ($d)" >&2; exit 2; }
  mutant "$m"
done < "$OUT/table"
# THE UNMUTATED COPY (MX0), built the way a mutant is: a copy in the mutant directory.
cp "$SUBJ" "$MUTDIR/MX0.sh" || { echo "FIXTURE ERROR: cannot copy the subject for MX0" >&2; exit 2; }
MX0_SAME=0; cmp -s "$SUBJ" "$MUTDIR/MX0.sh" && MX0_SAME=1

# JOBS. Every worker is `--run-one <arm> [<subject>]`: one arm, one process, one subject. Base arms
# run on the real subject. PER PUSH a mutant's cells are its DECIDING arm and its TWIN; under
# --matrix they are EVERY arm. One cell, run once, serves the verdict and the matrix row.
: > "$OUT/jobs"
while read -r m d t; do
  if [ "$MATRIX" -eq 1 ]; then cells="$ARMS"; else cells="$d
$t"; fi
  for a in $cells; do printf 'x.%s.%s|%s|%s\n' "$m" "$a" "$a" "$MUTDIR/$m.sh" >> "$OUT/jobs"; done
done < "$OUT/table"
if [ "$MATRIX" -eq 1 ]; then mx0_cells="$ARMS"; else mx0_cells="C06_regression_guards"; fi
for a in $mx0_cells; do printf 'x.MX0.%s|%s|%s\n' "$a" "$a" "$MUTDIR/MX0.sh" >> "$OUT/jobs"; done
for a in $NAMES; do printf 'b.%s|%s|-\n' "$a" "$a" >> "$OUT/jobs"; done

# EIGHT. This pool nests inside the pre-push suite's, so a knob here would multiply against a
# knob there; the cases sleep rather than compute, so eight of them cost about one core.
JOBS=8
AI_DLC_WS_SELF="$SELF" AI_DLC_WS_OUT="$OUT" \
  xargs -P "$JOBS" -I{} bash -c '
    IFS="|" read -r tag arm subj <<< "$1"
    bash "$AI_DLC_WS_SELF" --run-one "$arm" "$subj" "$AI_DLC_WS_OUT/$tag.pre" > "$AI_DLC_WS_OUT/$tag" 2> "$AI_DLC_WS_OUT/$tag.err"
    printf %s $? > "$AI_DLC_WS_OUT/$tag.rc"
  ' _ {} < "$OUT/jobs"

# BASE ARMS, rendered in SOURCE order, never completion order, so the output is byte-comparable against
# the serial version. A MISSING VERDICT IS A FAILURE: serially a case that never ran could not
# print an `ok`, because the loop and the report were the same thing. With a pool they are not,
# and a case that exits nonzero having printed nothing would add zero to the count -- which is
# what a clean case adds. An arm that passed sets B_<arm>=1, the same-run flag that gates the
# mutant verdicts below.
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ ! -f "$OUT/b.$n.rc" ]; then
    printf '  FAIL  %s produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one\n' "$n"
    fails=$((fails + 1))
    continue
  fi
  cat "$OUT/b.$n"
  [ -s "$OUT/b.$n.err" ] && cat "$OUT/b.$n.err" >&2
  wrc="$(cat "$OUT/b.$n.rc")"
  # 2 IS NOT 1. `FIXTURE BROKEN` and `an assertion regressed` are different answers, and this
  # file's helpers have always used exit 2 for the first. Running a case in a worker would
  # otherwise collapse them: the parent would see a nonzero rc, charge one assertion, and exit
  # 1 — reporting a regression where the truth is that nothing was tested.
  if [ "$wrc" = "2" ]; then broken=1; fi
  if [ "$wrc" = "0" ]; then eval "B_$n=1"; fi
  if [ "$wrc" != "0" ]; then
    c="$(grep -c '^  FAIL' "$OUT/b.$n" || true)"
    [ "$c" -gt 0 ] || { printf '  FAIL  %s exited nonzero without an assertion line — the case did not run to a verdict\n' "$n"; c=1; }
    fails=$((fails + c))
  fi
done <<EOF_NAMES
$NAMES
EOF_NAMES

# A CELL is one arm run under one subject. cell_state sets CELL_RC and CELL_FAILS, and CELL_OK=0 when
# the cell produced no verdict at all (the pool dropped it).
CELL_RC=""; CELL_FAILS=0; CELL_OK=0
cell_state() { # <mutant> <arm>
  CELL_OK=0; CELL_RC=""; CELL_FAILS=0
  [ -f "$OUT/x.$1.$2.rc" ] || return 0
  CELL_OK=1
  CELL_RC="$(cat "$OUT/x.$1.$2.rc")"
  CELL_FAILS="$(grep -c '^  FAIL' "$OUT/x.$1.$2" || true)"
}
# TRIPPED means the arm exited 1 having printed at least one FAIL line. Exit 2 is FIXTURE BROKEN and
# an exit 1 with no FAIL line printed nothing: neither is an arm tripping on the mutation.
cell_tripped() { [ "$CELL_OK" -eq 1 ] && [ "$CELL_RC" = "1" ] && [ "$CELL_FAILS" -gt 0 ]; }
cell_green() { [ "$CELL_OK" -eq 1 ] && [ "$CELL_RC" = "0" ]; }

# THE UNMUTATED COPY, driven through the same harness as a mutant. It must be byte-identical to the
# subject and its arm must pass, or every verdict below would be a verdict about the harness.
cell_state MX0 C06_regression_guards
B_MX0=0
if [ "$MX0_SAME" -eq 1 ] && cell_green && grep -q '^  ok' "$OUT/x.MX0.C06_regression_guards"; then
  ok "CONTROL MX0 (unmutated copy from the mutant directory): byte-identical to the subject, and the exhausted and absent arm passes under it"; B_MX0=1
else bad "CONTROL MX0: the unmutated copy (identical=$MX0_SAME, rc ${CELL_RC:-none}) did not pass the arm — the mutant harness is not running the shipped behaviour"; fi

# PER-MUTANT VERDICTS. The DECIDING arm must trip and the TWIN must stay green, so the kill is confined to
# the one arm. Both unmutated arms and MX0 must have PASSED in this run first (mutant_killed refuses
# otherwise): a deciding arm that already failed on the real subject would score every mutant dead.
n_dead=0
count_lines() { if [ -f "$1" ]; then grep -c . "$1" || true; else echo 0; fi; }
while read -r m d t; do
  bv="B_$d"; bt="B_$t"
  cell_state "$m" "$d"
  # A PRECONDITION FAILURE INSIDE A MUTANT CELL IS A FIXTURE ERROR, NEVER A KILL: the worker exits 2.
  if [ "$CELL_OK" -eq 1 ] && [ "$CELL_RC" = "2" ]; then
    bad "FIXTURE BROKEN: MUTANT $m on $d exited 2 — a precondition failed inside the mutant cell, so a trip there would not be earned"; broken=1; continue
  fi
  if cell_tripped; then dec_ok=1; else dec_ok=0; fi
  # The preconditions must have RUN under the mutant: as many control lines as the same arm printed on
  # the real subject. An arm that tripped before reaching them would otherwise score a kill unchecked.
  n_pre_m="$(count_lines "$OUT/x.$m.$d.pre")"; n_pre_b="$(count_lines "$OUT/b.$d.pre")"
  cell_state "$m" "$t"
  if [ "$CELL_OK" -eq 1 ] && [ "$CELL_RC" = "2" ]; then
    bad "FIXTURE BROKEN: MUTANT $m twin $t exited 2 — a precondition failed inside the mutant cell"; broken=1; continue
  fi
  if cell_green; then twin_ok=1; else twin_ok=0; fi
  if [ "$dec_ok" -eq 0 ]; then
    bad "MUTANT $m: deciding arm $d did not trip under the mutant — the mechanism is not what that arm measures"
  elif [ "$n_pre_m" != "$n_pre_b" ]; then
    bad "FIXTURE BROKEN: MUTANT $m on $d ran $n_pre_m precondition control(s) against $n_pre_b on the real subject — the kill is not earned"; broken=1
  elif [ "$twin_ok" -eq 0 ]; then
    bad "MUTANT $m: twin $t tripped (or gave no verdict) beside the deciding arm $d — the co-tripping changed; re-measure the matrix"
  else
    n_dead=$((n_dead + 1))
    # The same controls the arm printed under its own name, re-printed under the mutant's, so the kill's
    # preconditions are named per mutant.
    if [ -f "$OUT/x.$m.$d.pre" ]; then
      while IFS= read -r pl; do ok "MUTANT $m: ${pl#*: }"; done < "$OUT/x.$m.$d.pre"
    fi
    mutant_killed "$(( ${!bv:-0} && ${!bt:-0} && B_MX0 ))" "$m" "MUTANT $m: arm $d trips under the mutant while twin $t stays green"
  fi
done < "$OUT/table"

# THE MATRIX, printed only under --matrix: every (mutant | MX0) x arm cell, with that cell's OWN
# polarity. The tripped column is the arm's verdict under that subject, never the mutant's overall one.
MROWS=0
if [ "$MATRIX" -eq 1 ]; then
  { cat "$OUT/table"; echo "MX0 - -"; } > "$OUT/table.all"
  mx_bad=0; mx_pre=0
  while read -r m d t; do
    for a in $ARMS; do
      cell_state "$m" "$a"
      if [ "$CELL_OK" -ne 1 ]; then mx_bad=$((mx_bad + 1)); continue; fi
      # rc 2 is a precondition failing inside the cell: the arm never reached its target, so the cell is neither
      # green nor an arm tripping, and it is printed as such (killed=no). Only a DECIDING or TWIN cell at rc 2
      # is fatal, and the verdict loop above already refuses that.
      if [ "$CELL_RC" = "0" ]; then matrix_row "$m" "$a" "$CELL_RC" GREEN no
      elif [ "$CELL_RC" = "2" ]; then mx_pre=$((mx_pre + 1)); matrix_row "$m" "$a" "$CELL_RC" PRECONDITION no
      else matrix_row "$m" "$a" "$CELL_RC" TRIPPED yes; fi
      MROWS=$((MROWS + 1))
    done
  done < "$OUT/table.all"
  want_rows=$(( (N_MUT + 1) * N_ARMS ))
  if [ "$MROWS" -eq "$want_rows" ] && [ "$mx_bad" -eq 0 ]; then ok "MATRIX: $MROWS cells printed, one per mutant-or-MX0 and arm"
  else bad "MATRIX: $MROWS of $want_rows cells printed ($mx_bad produced no verdict)"; fi
  ok "MATRIX: $mx_pre non-deciding cell(s) failed a precondition and are printed PRECONDITION, not TRIPPED"
  # MX0 must be GREEN on every arm: a tripped MX0 cell is the harness, not a mutant.
  mx0_tripped=0
  for a in $ARMS; do cell_state MX0 "$a"; cell_green || mx0_tripped=$((mx0_tripped + 1)); done
  if [ "$mx0_tripped" -eq 0 ]; then ok "CONTROL MX0: the unmutated copy trips none of the $N_ARMS arms"
  else bad "CONTROL MX0: the unmutated copy tripped $mx0_tripped arm(s) — the harness is not neutral"; fi
else
  # A PLAIN run carries no matrix-only cell: the whole matrix block above is behind the flag.
  if [ "$MROWS" -eq 0 ] && ! grep -q '^  MATRIX ' "$OUT/b.C06_regression_guards"; then ok "PLAIN-RUN: no matrix row printed and no matrix-only cell scheduled (jobs: $(grep -c '^x\.' "$OUT/jobs") mutant cells)"
  else bad "PLAIN-RUN: a matrix row was printed by a plain run"; fi
fi

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
