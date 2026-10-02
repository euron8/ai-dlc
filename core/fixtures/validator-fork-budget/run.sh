#!/usr/bin/env bash
# Hold scripts/validate-enforcement-map.sh to the FORK_BUDGET it declares about itself.
#
# WHY THIS FIXTURE EXISTS. That script stated its own cost in a comment -- a fork count, a
# per-fork cost, and the CPU-seconds the suite pays for it. Every figure was true when
# written, nothing read the sentence, and by the time anyone re-measured it was several times
# low while reading exactly like a fresh measurement. The budget is now a line of code
# (`FORK_BUDGET=` in that file) and this is its reader. A prose number decays silently; a
# gated one decays into a failed push.
#
# WHY FORK COUNT AND NOT WALL CLOCK. The rejection is recorded beside `FORK_BUDGET` itself and
# is not restated here: it is about pool contention and about the resolution a loaded-box
# threshold can reach. What matters at this end is that fork count is deterministic and
# load-independent, which is what lets arm A2 assert EQUALITY across two runs rather than a
# tolerance -- and a tolerance is how a gate becomes the flaky thing people push past.
#
# THE ARMS, IN THE ORDER `judge` EVALUATES THEM, ALL OF THEM REQUIRED. Drop any one and the
# gate passes vacuously.
#
#   A0  self-probe   the profiler counts a known-50 script as 50, a fork-free one as 0, and
#                    an assignment probe as exactly its 3 near-misses
#   A2  determinism  the reading was REPRODUCED; an unreproduced one is BROKEN, never a red
#   A1  floor        a measurement at or below what a BROKEN subject measures, profiled live
#   A5  wholeness    the traced run exited 0 and reached past the LAST arm header's line
#   A3  ceiling      measured <= FORK_BUDGET
#   A4  stale-high   measured >= 70% of FORK_BUDGET, or the budget has ratcheted out of reach
#
# A1 AND A5 ARE THE TWO THAT MAKE THE OTHERS MEAN ANYTHING. A validator that dies at line 400
# forks almost nothing and sails under any ceiling; an unbounded-below gate reads that as an
# infinitely fast validator and prints the same green line it prints for a healthy one.
#
# THE VERDICT IS TWO FUNCTIONS, `judge` and `stable_verdict`, and the mutants below drive those
# same functions rather than a second copy of their logic. m0 and m1 drive the WHOLE pipeline,
# because neither function can see a tracer that stopped tracing: m0 profiles a subject that
# runs almost nothing, which is the "would this arm pass against a program that emits nothing"
# question this repository's mutant rule asks of every absence-shaped arm, and m1 profiles with
# the PS4 marker neutered. m2-m6 drive `judge`, one per arm, each with exactly one field moved
# and its own budget derived from the live reading, so no mutant can fail on another's arm.
# m7 drives `stable_verdict` with a profiler that accepts `--stable` and ignores it. m8 and m9
# drive `judge` at the COMMITTED budget: m8 inside A4's window, m9 one fork above the floor.
# m10-m12 drive the profiler's own assignment probe with its classifier mutated three ways --
# reverted, `+=` dropped, widened -- so the classifier fix cannot be undone without a red.
#
# WHERE THIS FIXTURE'S TIME GOES, because it became the suite's second-longest unit and the
# obvious guess is wrong. Instrumented solo, 32.2s wall / 36.0 CPU-seconds: the `--stable`
# corpus reading is 31 of the 32, and everything else -- the self-probe, all six arms, and all
# eight mutants together -- is the remaining second. m1 costs nothing because the profiler's
# own self-probe refuses before it ever reaches the validator, and m0/m7 profile a three-line
# script. So there is no mutant to trim and no arm to shard: the unit IS one reading, and the
# only lever on it is how the reading is taken. That lever lives in scripts/fork-profile.sh,
# which now takes its reps two at a time.
#
# Exit 0 iff the live verdict is PASS and every mutant is killed by its own arm.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"

# BOTH LAYOUTS NAMED, never a single walk-up (I33c). Here the fixture sits at
# core/fixtures/<name>/; the consumer layout puts it at tests/fixtures/<name>/. This unit is
# .dist-only and only ever runs here, but a resolver that names one layout is the shape the
# invariant forbids, and a fixture is not the place to make an exception to it.
REPO=""
for cand in "$DIR/../../.." "$DIR/../.."; do
  if [ -f "$cand/VERSION" ] && [ -f "$cand/scripts/fork-profile.sh" ]; then
    REPO="$(cd "$cand" && pwd)"; break
  fi
done
if [ -z "$REPO" ]; then
  echo "FIXTURE ERROR: could not locate the repo root (VERSION + scripts/fork-profile.sh) from $DIR" >&2
  exit 2
fi
PROFILER="$REPO/scripts/fork-profile.sh"
VAL="$REPO/scripts/validate-enforcement-map.sh"
[ -f "$VAL" ] || { echo "FIXTURE ERROR: missing $VAL" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
# EVERY `ok    m<n>` LINE COUNTS ITSELF, so the closing tally cannot go stale.
#
# It read `8/8 mutants killed` as a literal, and the release that added `m8` left it saying
# 8 while nine had run -- a hardcoded count decaying silently inside the fixture whose entire
# subject is a hardcoded count decaying silently. Derived from the notes actually emitted.
N_KILLED=0
note() {
  case "$1" in ok*m[0-9]*) N_KILLED=$((N_KILLED + 1)) ;; esac
  printf '%s\n' "$*"
}

# --- the budget, read from the ONE line that declares it ---------------------------------
# ANCHORED AT COLUMN 0 AND COUNTED. A whole-file grep for `FORK_BUDGET` is satisfied by the
# paragraph above the assignment, and a paragraph is not a value. Exactly one declaring line
# must exist: zero means the declaration moved and this fixture would be judging against an
# empty string, two means a reader elsewhere could take the other one.
BUDGET_LINES="$(grep -cE '^FORK_BUDGET=[0-9]+$' "$VAL")"
if [ "$BUDGET_LINES" -ne 1 ]; then
  note "FIXTURE BROKEN: $VAL declares $BUDGET_LINES line(s) matching '^FORK_BUDGET=<n>$'; exactly 1 is required."
  exit 1
fi
BUDGET="$(sed -n 's/^FORK_BUDGET=\([0-9][0-9]*\)$/\1/p' "$VAL")"

# Corpus size, reported alongside the absolute number so that a future reading can tell
# CORPUS GROWTH from an algorithmic regression. It is deliberately NOT a divisor: a
# forks-per-fixture ratio absorbs a regression silently as the suite grows, which is exactly
# how the prose figure this gate replaces came to be several times low.
FXROOT="$REPO/core/fixtures"
[ -d "$FXROOT" ] || FXROOT="$REPO/tests/fixtures"
NFX="$(find "$FXROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -c .)"

# --- judge: the whole verdict, one implementation -----------------------------------------
# judge <total> <exit> <maxline> <lastarm> <budget> -> "PASS" | "RED <why>" | "BROKEN <why>"
# Reads the global `$FLOOR`, which is profiled live below before the first call.
# Arm order is the order in the header and it is load-bearing: a subject that died early is
# caught by A1 when it died at the top and by A5 when it died anywhere else, and A3/A4 are
# only meaningful once both of those have been ruled out -- which is why A5 now runs BEFORE
# them. With the floor near zero, a validator that dies after a few hundred forks passes A1;
# evaluated after A4 it read "stale-high, lower the budget", a broken subject with a remedy
# that would ratchet the budget onto it.
judge() {
  local t="$1" ex="$2" mx="$3" la="$4" b="$5"
  case "$t" in ''|*[!0-9]*) echo "BROKEN the profiler reported no numeric TOTAL ('$t'); a tracer that produced nothing is not a validator that forked nothing"; return ;; esac
  case "$b" in ''|*[!0-9]*) echo "BROKEN no numeric FORK_BUDGET ('$b')"; return ;; esac
  case "${FLOOR:-}" in ''|*[!0-9]*) echo "BROKEN no numeric broken-subject FLOOR ('${FLOOR:-}')"; return ;; esac
  # A1 floor -- WHAT A BROKEN SUBJECT MEASURES, profiled in this run, never a fraction.
  #
  # HISTORY, BECAUSE BOTH EARLIER FORMS FAILED.
  # IT WAS A HARDCODED 5000, SIZED WHEN THE VALIDATOR FORKED 8225, AND IT BROKE TWICE OVER.
  # First directly: the release that took I59 and I60 from 1724 forks to 66 landed the true
  # reading at 4767, BELOW the constant, so the fixture reported the subject's own improvement
  # as `BROKEN ... a broken tracer, an unmatched marker or a validator that exited early`, and
  # m2/m3/m5/m6 all went off on this arm instead of their own -- five failures from one
  # correct change, which is this file's own sign that an assertion is vacuous.
  #
  # Second, and silently, it took A4 WITH IT. A4 fires only when `t*10 < b*7`, so with a
  # constant floor it needs `5000 < t < 0.7*b`, which is EMPTY for every budget at or below
  # 7143. Measured across the budgets this file has actually carried: b=8225 (0.583.0) left a
  # window of 5001..5756; b=6431 (0.587.0) left NONE. So A4 -- the arm whose whole subject is
  # "a ceiling nothing can reach reads exactly like one that passed" -- had itself become a
  # check that could not fire, one release before this one, and nothing said so. `m3` could
  # not see it because it drives `judge` with a budget derived from `$T1`, where the window
  # is never empty; a mutant wired to a derived value keeps a dead arm looking alive.
  #
  # The next form was 40% of the budget, which fixed both of those and was still a fraction of
  # the CEILING standing in for a property of the TRACER. Nothing joined `4/10` to what a broken
  # subject reads, so a ratchet far enough down would have put a broken reading above it, and a
  # receipt keyed on the literal `b * 4 / 10` was satisfied by respelling it `b * 2 / 5`.
  #
  # NOW THE FLOOR IS THE MEASUREMENT. The largest TOTAL this run's profiler reports for the
  # broken subjects, profiled below: a script that forks nothing, and a copy of the validator
  # cut at line 400 that dies at its required-input check. Measured: 0 and 1. The third broken
  # case, the PS4 marker neutered, yields no TOTAL at all because the profiler's self-probe
  # refuses first (m1), so it cannot contribute a number. A deeper truncation reads hundreds or
  # thousands of forks and is not this arm's subject: it exits non-zero or stops short of the
  # last arm, and A5 refuses it.
  #
  # A4's window is `FLOOR < t < 0.7b`, non-empty for every budget above 10*FLOOR/7 -- a
  # handful of forks today. m8 constructs its midpoint at the committed budget, so a floor
  # that ever rises to meet the ceiling fails the push rather than silencing A4.
  if [ "$t" -le "$FLOOR" ]; then
    echo "BROKEN measured $t fork(s), at or below the floor of $FLOOR (the most a broken subject reads under this profiler, measured this run). That is a broken tracer, an unmatched marker or a validator that exited early -- not a fast validator. An unbounded-below gate reads a dead subject as an infinitely fast one."
    return
  fi
  # A5 wholeness
  if [ "$ex" != "0" ]; then
    echo "BROKEN the traced run exited $ex. A validator that failed did not necessarily execute its whole self, so its fork count is not the number this budget is about."
    return
  fi
  case "$la" in ''|*[!0-9]*) echo "BROKEN no numeric LASTARM; the arm grammar produced no header line, so 'the trace reached the last arm' cannot be evaluated"; return ;; esac
  if [ "$la" -le 0 ]; then
    echo "BROKEN LASTARM is $la: the arm map is empty, so a run that stopped anywhere would satisfy the wholeness arm"
    return
  fi
  case "$mx" in ''|*[!0-9]*) echo "BROKEN no numeric MAXLINE"; return ;; esac
  if [ "$mx" -lt "$la" ]; then
    echo "BROKEN the trace's highest source line is $mx but the last arm header is at line $la, so the run never reached the final arm. A validator that dies partway forks very little and would sail under any ceiling."
    return
  fi
  # A3 ceiling
  if [ "$t" -gt "$b" ]; then
    echo "RED measured $t fork(s) against FORK_BUDGET=$b ($((t - b)) over). Across $NFX fixture directories that is $((t / (NFX > 0 ? NFX : 1))) fork(s) per fixture. The suite runs this validator well over a hundred times per full push, so this is a change to the suite's wall clock. Either remove the forks (scripts/fork-profile.sh --section by-line names the sites) or raise FORK_BUDGET in $VAL as a deliberate one-line diff."
    return
  fi
  # A4 stale-high
  if [ "$((t * 10))" -lt "$((b * 7))" ]; then
    echo "RED measured $t fork(s) against FORK_BUDGET=$b -- under 70% of it. The budget is stale-high; lower it to near $t. A ceiling nothing can reach is a check that cannot fire, and it reads exactly like one that passed."
    return
  fi
  echo "PASS"
}

field() { awk -v k="$2" '$1 == k { print $2; exit }' "$1"; }

# --- A2's predicate, factored out so its mutant can drive the same code -------------------
# stable_verdict <n-stable> -> "OK" | "BROKEN <why>"
stable_verdict() {
  case "${1:-}" in ''|*[!0-9]*)
    echo "BROKEN the profiler reported no STABLE count ('${1:-}'). A build that accepts --stable and ignores it returns ONE unreproduced reading, which is exactly what this arm exists to refuse."
    return ;;
  esac
  if [ "$1" -lt 2 ]; then
    echo "BROKEN the reading was reproduced only $1 time(s); a reading nobody can take twice is not a measurement"
    return
  fi
  echo OK
}

# ==========================================================================================
# A0 -- THE SELF-PROBE, BEFORE THE CORPUS.
# The profiler runs both directions itself on every invocation and reports them beside TOTAL,
# so the probe reading and the corpus reading always come from ONE run of ONE program. This
# arm asserts them; it does not recompute them, because a second implementation of the probe
# is a second set of bugs.
# ==========================================================================================
if ! bash "$PROFILER" --probe-only > "$TMP/probe.out" 2>"$TMP/probe.err"; then
  note "FIXTURE BROKEN: the profiler's own self-probe failed."
  sed 's/^/      /' "$TMP/probe.err" | head -5
  exit 1
fi
P_POS="$(field "$TMP/probe.out" PROBEPOS)"
P_NEG="$(field "$TMP/probe.out" PROBENEG)"
# PROBEASG is the assignment probe: its assignment shapes score 0 and its three near-misses 1
# each. It is a separate reading with its own expected count, so PROBEPOS still means 50.
P_ASG="$(field "$TMP/probe.out" PROBEASG)"
if [ "$P_POS" != "50" ] || [ "$P_NEG" != "0" ] || [ "$P_ASG" != "3" ]; then
  note "FIXTURE BROKEN: self-probe returned PROBEPOS=$P_POS PROBENEG=$P_NEG PROBEASG=$P_ASG; must be 50, 0 and 3."
  exit 1
fi
note "ok    A0 self-probe   -- a known-50 script counts 50, a fork-free one counts 0, the assignment probe counts only its 3 near-misses"

# ==========================================================================================
# THE FLOOR -- what a BROKEN subject reads under THIS profiler, measured before the corpus.
# `judge`'s A1 explains why it is a measurement and not a fraction. Two subjects: a script that
# runs almost nothing (also m0's subject, so m0 reads this same profile), and the validator cut
# at line 400 under $TMP, where its root resolves to nowhere and it dies at its required-input
# check. Both must yield a numeric TOTAL; a floor taken from a profile that produced none is
# a floor of zero by accident.
# ==========================================================================================
printf '%s\n' '#!/usr/bin/env bash' 'x=1' 'exit 0' > "$TMP/tiny.sh"
mkdir -p "$TMP/cut/scripts"
head -400 "$VAL" > "$TMP/cut/scripts/validate-enforcement-map.sh"
FLOOR=""
for fs in tiny:"$TMP/tiny.sh" cut:"$TMP/cut/scripts/validate-enforcement-map.sh"; do
  fs_name="${fs%%:*}"; fs_path="${fs#*:}"
  if ! bash "$PROFILER" --target "$fs_path" --section total > "$TMP/floor-$fs_name.out" 2>"$TMP/floor-$fs_name.err"; then
    note "FIXTURE BROKEN: the profiler could not profile the broken subject '$fs_name' at all, so the floor is unknown."
    sed 's/^/      /' "$TMP/floor-$fs_name.err" | head -3
    exit 1
  fi
  fs_t="$(field "$TMP/floor-$fs_name.out" TOTAL)"
  case "$fs_t" in ''|*[!0-9]*)
    note "FIXTURE BROKEN: the broken subject '$fs_name' produced no numeric TOTAL ('$fs_t'), so the floor is unknown."
    exit 1 ;;
  esac
  if [ -z "$FLOOR" ] || [ "$fs_t" -gt "$FLOOR" ]; then FLOOR="$fs_t"; fi
done
cp "$TMP/floor-tiny.out" "$TMP/m0.out"

# ==========================================================================================
# THE CORPUS -- `--stable`, which re-profiles the real validator until a total repeats.
# ==========================================================================================
if ! bash "$PROFILER" --section total --stable > "$TMP/r1.out" 2>"$TMP/r1.err"; then
  note "FIXTURE BROKEN: the profiler could not produce a repeated reading of the real validator."
  sed 's/^/      /' "$TMP/r1.err" | head -5
  exit 1
fi

T1="$(field "$TMP/r1.out" TOTAL)"
EX="$(field "$TMP/r1.out" EXIT)"
MX="$(field "$TMP/r1.out" MAXLINE)"
LA="$(field "$TMP/r1.out" LASTARM)"
N_REPS="$(field "$TMP/r1.out" REPS)"
N_STABLE="$(field "$TMP/r1.out" STABLE)"
SPREAD="$(field "$TMP/r1.out" SPREAD)"

# --- A2 determinism -----------------------------------------------------------------------
# A DISAGREEMENT IS BROKEN, NEVER RED. Fork count is a property of the program, not of the box;
# a reading nobody can take twice must never be reported as a regression in the change under
# test, because that is how a gate earns a reputation for lying and gets pushed past.
#
# THE ARM ASSERTS A REPRODUCED READING, NOT TWO EQUAL ONES, and the difference is measured
# rather than conceded. Five profiles of one unchanged tree on a loaded box split 3/2 between
# 6553 and 6552 forks, and the low reading's rows were a strict SUBSET of the high one's -- one
# dropped xtrace line from one stage of a four-stage pipeline. Requiring two RAW runs to be
# equal therefore fails on an unchanged tree roughly half the time on a busy box. The profiler
# re-reads until a value repeats and reports the largest repeated one; a dropped line can only
# subtract, so a spuriously HIGH answer is unconstructible and this is not a tolerance.
A2V="$(stable_verdict "${N_STABLE:-}")"
if [ "$A2V" != "OK" ]; then
  note "FIXTURE BROKEN: ${A2V#BROKEN } (REPS=$N_REPS, spread $SPREAD)"
  exit 1
fi
note "ok    A2 determinism  -- $T1 fork(s) reproduced ${N_STABLE}x over $N_REPS rep(s), spread $SPREAD"

VERDICT="$(judge "$T1" "$EX" "$MX" "$LA" "$BUDGET")"
case "$VERDICT" in
  PASS)
    note "ok    A1 floor       -- $T1 forks is above the broken-subject floor of $FLOOR (the most a broken subject read this run)"
    note "ok    A3 ceiling     -- $T1 <= FORK_BUDGET=$BUDGET ($((BUDGET - T1)) of headroom, $NFX fixture dirs)"
    note "ok    A4 stale-high  -- $T1 is at least 70% of $BUDGET, so the ceiling is still reachable"
    note "ok    A5 wholeness   -- traced run exited $EX and reached line $MX, past the last arm header at $LA"
    ;;
  *)
    note "FAIL  validator-fork-budget -- ${VERDICT}"
    rc=1
    ;;
esac

# ==========================================================================================
# THE MUTANTS. Each must be killed, and by its own arm.
# ==========================================================================================
kill_j() { # kill_j <name> <expected-class> <expected-substring> <judge args...>
  local n="$1" cls="$2" pat="$3"; shift 3
  local out; out="$(judge "$@")"
  case "$out" in
    "$cls"*) : ;;
    *) note "FAIL  $n -- expected a $cls verdict, got: $out"; rc=1; return ;;
  esac
  case "$out" in
    *"$pat"*) note "ok    $n -- killed by its own arm" ;;
    *) note "FAIL  $n -- $cls, but not on its own assertion (wanted: $pat) -- got: $out"; rc=1 ;;
  esac
}

# m0 -- THE WHOLE PIPELINE against a subject that runs almost nothing. This is the mutant the
# repository's rule demands of any absence-shaped arm: would the gate print `ok` for a program
# that emits nothing? It must not. It reads the profile the floor derivation already took of
# the same subject, so the subject is profiled once.
m0_v="$(judge "$(field "$TMP/m0.out" TOTAL)" "$(field "$TMP/m0.out" EXIT)" \
              "$(field "$TMP/m0.out" MAXLINE)" "$(field "$TMP/m0.out" LASTARM)" "$BUDGET")"
case "$m0_v" in
  BROKEN*floor*) note "ok    m0 empty-subject  -- a subject that forks nothing is BROKEN, not a pass" ;;
  *) note "FAIL  m0 empty-subject -- a near-forkless subject produced: $m0_v"; rc=1 ;;
esac

# m1 -- THE MARKER NEUTERED. `PS4` is what separates trace from the subject's own stderr, and
# there is no fd to separate them by on bash 3.2. A profiler whose marker no longer matches
# sees an empty trace and would report a very small number -- which, without A1, is
# indistinguishable from a validator that got faster. judge cannot see this one, so the mutant
# drives the whole pipeline.
#
# THE COPY NEEDS A ROOT OR IT DIES BEFORE IT CAN BE WRONG. The profiler walks up for a VERSION
# marker, so a copy dropped in a bare temp dir exits 2 with "no VERSION marker" -- which is a
# refusal, not the neutered-marker reading this mutant is about, and scoring it as a kill would
# credit the arm for a failure it never tested. The sandbox carries a VERSION and the real
# validator is named absolutely.
mkdir -p "$TMP/fake/scripts"
echo "0.0.0" > "$TMP/fake/VERSION"
cp "$PROFILER" "$TMP/fake/scripts/fp-neutered.sh"
if sed "s/PS4='+@\${LINENO}@ '/PS4='+ '/" "$TMP/fake/scripts/fp-neutered.sh" > "$TMP/fp-n2.sh" \
   && ! cmp -s "$TMP/fake/scripts/fp-neutered.sh" "$TMP/fp-n2.sh"; then
  mv "$TMP/fp-n2.sh" "$TMP/fake/scripts/fp-neutered.sh"
  if bash "$TMP/fake/scripts/fp-neutered.sh" --section total --target "$VAL" > "$TMP/m1.out" 2>"$TMP/m1.err"; then
    m1_v="$(judge "$(field "$TMP/m1.out" TOTAL)" "$(field "$TMP/m1.out" EXIT)" \
                  "$(field "$TMP/m1.out" MAXLINE)" "$(field "$TMP/m1.out" LASTARM)" "$BUDGET")"
    case "$m1_v" in
      BROKEN*) note "ok    m1 marker-neutered -- a neutered PS4 reads as BROKEN, not as a pass" ;;
      *) note "FAIL  m1 marker-neutered -- a profiler that traces nothing produced: $m1_v"; rc=1 ;;
    esac
  elif grep -q 'SELF-PROBE FAILED' "$TMP/m1.err"; then
    note "ok    m1 marker-neutered -- the profiler's own self-probe refused to answer at all"
  else
    note "FAIL  m1 marker-neutered -- the profiler failed, but not on its self-probe"
    sed 's/^/      /' "$TMP/m1.err" | head -3; rc=1
  fi
else
  note "SKIP  m1 -- the PS4 sed matched nothing; no mutation occurred, so nothing was proven"; rc=1
fi

# m2-m6 -- one per judge arm, driven with the REAL readings and exactly one field moved.
#
# EVERY ONE OF THEM PASSES ITS OWN BUDGET, DERIVED FROM `$T1`, NEVER THE COMMITTED ONE. These
# mutants exist to prove that each ARM of `judge` discriminates; whether today's FORK_BUDGET
# happens to be satisfied is a different question, owned by the live verdict above. Wiring them
# to `$BUDGET` entangled them with it -- MEASURED, by setting FORK_BUDGET below the truth to
# demonstrate a red: m5 and m6 both went off on the CEILING arm instead of their own, because
# the ceiling fires first. Two failures from one mutation is this repository's sign that an
# assertion is vacuous, and it was.
kill_j "m2 ceiling      budget one below the truth" RED "over" \
       "$T1" "$EX" "$MX" "$LA" "$((T1 - 1))"
kill_j "m3 stale-high   budget at twice the truth"  RED "stale-high" \
       "$T1" "$EX" "$MX" "$LA" "$((T1 * 2))"
kill_j "m4 floor        a measurement AT the floor"  BROKEN "floor" \
       "$FLOOR" "$EX" "$MX" "$LA" "$T1"
kill_j "m5 wholeness    trace stops before the last arm" BROKEN "never reached the final arm" \
       "$T1" "$EX" "$((LA - 1))" "$LA" "$T1"
kill_j "m6 wholeness    the traced run exited non-zero" BROKEN "exited 2" \
       "$T1" "2" "$MX" "$LA" "$T1"

# m8 -- A4 IS REACHABLE AT THE COMMITTED BUDGET, and this is the one mutant that must be
# wired to `$BUDGET` rather than to `$T1`.
#
# THE ARM ABOVE SAYS WHY. A1 and A4 bound `t` from opposite sides, so whether A4 has any
# window at all is a property of the FLOOR and the BUDGET together -- and m3, driven at
# `$T1 * 2`, has a window under any floor and therefore cannot see the window at the
# committed budget closing. That is exactly what happened: with the old constant floor, A4
# was unreachable at every budget at or below 7143, `m3` stayed green through it, and the
# arm whose subject is "a ceiling nothing can reach reads exactly like one that passed" had
# become one itself.
#
# Constructed rather than asserted: the midpoint of A4's window at the LIVE budget. If the
# window is empty the midpoint is not inside it, no arm fires, and `kill_j` reports the
# mutant as unkilled -- which is the reading this mutant exists to produce.
M8_LO="$FLOOR"
M8_HI="$((BUDGET * 7 / 10))"
M8_T="$(( (M8_LO + M8_HI) / 2 ))"
if [ "$M8_LO" -lt "$M8_HI" ] && [ "$M8_T" -gt "$M8_LO" ] && [ "$M8_T" -lt "$M8_HI" ]; then
  kill_j "m8 A4-reachable a total inside A4's window at the LIVE budget" RED "stale-high" \
         "$M8_T" "$EX" "$MX" "$LA" "$BUDGET"
else
  note "FAIL  m8 A4-reachable -- A4 has NO window at FORK_BUDGET=$BUDGET (floor $M8_LO, stale-high below $M8_HI). The stale-high arm cannot fire for any measurement whatsoever, and a check that cannot fire reads exactly like one that passed."
  rc=1
fi

# m9 -- THE FLOOR IS THE MEASURED ONE, NOT A FRACTION OF THE CEILING. One fork above what a
# broken subject reads, at the committed budget, must clear A1 and land on A4. Any fraction of
# the budget puts the floor in the hundreds or thousands and refuses this input as BROKEN, so
# respelling the old `4/10` in any form fails here. That is the input m4 and m8 cannot supply:
# m4 sits at the floor, and m8 sits at a midpoint every fraction below 0.7 also clears.
kill_j "m9 floor-tight  one fork above the measured floor" RED "stale-high" \
       "$((FLOOR + 1))" "$EX" "$MX" "$LA" "$BUDGET"

# m7 -- A PROFILER THAT ACCEPTS `--stable` AND IGNORES IT. Without this, A2 is a guard with no
# subject: on exit 0 the profiler's own contract already guarantees a repeated reading, so the
# only way the arm can ever fire is a build whose `--stable` does nothing -- an older copy, a
# bad merge, a flag renamed on one side of the join. Driven against the trivial target so the
# mutant costs a second rather than another full profile; the arm's predicate is the STABLE
# field, not the total.
mkdir -p "$TMP/fake2/scripts"
echo "0.0.0" > "$TMP/fake2/VERSION"
if sed 's/--stable)  STABLE=1; shift ;;/--stable)  shift ;;/' "$PROFILER" > "$TMP/fake2/scripts/fp-nostable.sh" \
   && ! cmp -s "$PROFILER" "$TMP/fake2/scripts/fp-nostable.sh"; then
  if bash "$TMP/fake2/scripts/fp-nostable.sh" --target "$TMP/tiny.sh" --section total --stable \
       > "$TMP/m7.out" 2>"$TMP/m7.err"; then
    m7_v="$(stable_verdict "$(field "$TMP/m7.out" STABLE)")"
    case "$m7_v" in
      BROKEN*) note "ok    m7 stable-ignored -- an unreproduced reading is BROKEN, not a pass" ;;
      *) note "FAIL  m7 stable-ignored -- a profiler that ignores --stable produced: $m7_v"; rc=1 ;;
    esac
  else
    note "FAIL  m7 stable-ignored -- the mutated profiler did not run at all"
    sed 's/^/      /' "$TMP/m7.err" | head -3; rc=1
  fi
else
  note "SKIP  m7 -- the --stable sed matched nothing; no mutation occurred, so nothing was proven"; rc=1
fi

# m10-m12 -- THE ASSIGNMENT CLASSIFIER IS LOAD-BEARING, IN BOTH DIRECTIONS. Each is a copy of
# the profiler with `is_assign` changed one way, run `--probe-only` from a root that carries a
# VERSION, and each must be refused by the ASSIGNMENT probe and by nothing else -- a refusal from
# the positive or negative probe would be a kill this arm did not earn.
#   m10  the classifier before the fix: one regex, brackets holding no `]`, an `=` tail only
#   m11  balanced brackets kept, the `+=` tail dropped
#   m12  widened: anything after a bracket, then an `=` -- scores the near-miss `a[1]x=3` as
#        an assignment, which is the direction a too-generous fix would take
# The unmutated copy in the same root must PASS and print PROBEASG 3 first, so a root the
# profiler cannot run from cannot score three kills.
mkdir -p "$TMP/fake3/scripts"
echo "0.0.0" > "$TMP/fake3/VERSION"
cp "$PROFILER" "$TMP/fake3/scripts/fp-ctl.sh"
# `--target` names a file that exists: the profiler refuses a missing target before any probe.
if bash "$TMP/fake3/scripts/fp-ctl.sh" --target "$TMP/tiny.sh" --probe-only > "$TMP/asgctl.out" 2>"$TMP/asgctl.err" \
   && [ "$(field "$TMP/asgctl.out" PROBEASG)" = "3" ]; then
  ASG_LINE='  if (is_assign(cmd)) next'
  if [ "$(grep -cxF -- "$ASG_LINE" "$PROFILER")" != "1" ] \
     || [ "$(grep -cxF -- '  if (substr(w, i, 2) == "+=") return 1' "$PROFILER")" != "1" ]; then
    note "FAIL  m10-m12 -- an anchor line is not unique in $PROFILER; no mutation can be trusted"; rc=1
  else
    asg_mut() { # asg_mut <name> <sed-expression>
      local n="$1" f="$TMP/fake3/scripts/fp-$1.sh"
      if ! sed "$2" "$PROFILER" > "$f" || cmp -s "$PROFILER" "$f"; then
        note "SKIP  $n -- the sed did not apply; no mutation occurred, so nothing was proven"; rc=1; return
      fi
      if bash "$f" --target "$TMP/tiny.sh" --probe-only > "$TMP/$n.out" 2>"$TMP/$n.err"; then
        note "FAIL  $n -- the mutated classifier passed the self-probe (PROBEASG=$(field "$TMP/$n.out" PROBEASG))"; rc=1
      # The second conjunct has no subject while the assignment probe runs last (the profiler
      # exits at its first failing probe); it guards a reordering that would let one mutant
      # trip two probes and be credited to this one.
      elif grep -q 'the assignment probe must score' "$TMP/$n.err" \
           && ! grep -q 'positive probe\|fork-free probe' "$TMP/$n.err"; then
        note "ok    $n -- killed by the assignment probe"
      else
        note "FAIL  $n -- the profiler refused, but not on the assignment probe:"
        sed 's/^/      /' "$TMP/$n.err" | head -3; rc=1
      fi
    }
    asg_mut "m10 asg-preBL417" 's|^  if (is_assign(cmd)) next$|  if (cmd ~ /^[A-Za-z_][A-Za-z0-9_]*(\\[[^]]*\\])?=/) next|'
    asg_mut "m11 asg-no-plus"  '/^  if (substr(w, i, 2) == "+=") return 1$/d'
    asg_mut "m12 asg-widened"  's|^  if (is_assign(cmd)) next$|  if (cmd ~ /^[A-Za-z_][A-Za-z0-9_]*(\\[.*)?=/) next|'
  fi
else
  note "FAIL  m10-m12 -- the UNMUTATED profiler copy did not pass --probe-only with PROBEASG 3 from its sandbox root, so no mutant verdict means anything"
  sed 's/^/      /' "$TMP/asgctl.err" | head -3; rc=1
fi

# THE MUTANT FLOOR. `rc` is 0 when every mutant that RAN was killed, which is also what it
# reads when a refactor deletes the mutants -- two inert runs compare equal. The floor is the
# count this file is known to carry; it rises with a new mutant and refuses a run that
# silently lost one.
EXPECTED_MUTANTS=13
if [ "$rc" -eq 0 ] && [ "$N_KILLED" -lt "$EXPECTED_MUTANTS" ]; then
  note "FAIL  validator-fork-budget -- only $N_KILLED of $EXPECTED_MUTANTS mutants were killed. A battery that lost a mutant reports the same green line as one that killed them all."
  rc=1
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  validator-fork-budget -- $T1 fork(s) of FORK_BUDGET=$BUDGET across $NFX fixture dirs; 6 arms green, $N_KILLED/$EXPECTED_MUTANTS mutants killed"
fi
exit "$rc"
