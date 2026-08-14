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
# THE ARMS, IN THIS ORDER, ALL OF THEM REQUIRED. Drop any one and the gate passes vacuously.
#
#   A0  self-probe   the profiler counts a known-50 script as 50 and a fork-free one as 0
#   A1  floor        a measurement at or below 5000 is a BROKEN tracer, never a fast validator
#   A2  determinism  the reading was REPRODUCED; an unreproduced one is BROKEN, never a red
#   A3  ceiling      measured <= FORK_BUDGET
#   A4  stale-high   measured >= 70% of FORK_BUDGET, or the budget has ratcheted out of reach
#   A5  wholeness    the traced run exited 0 and reached past the LAST arm header's line
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
# m7 drives `stable_verdict` with a profiler that accepts `--stable` and ignores it.
#
# Exit 0 iff the live verdict is PASS and all eight mutants are killed by their own arm.
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
note() { printf '%s\n' "$*"; }

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
# Arm order is the order in the header and it is load-bearing: a subject that died early is
# caught by A1 when it died at the top and by A5 when it died at the bottom, and A3/A4 are
# only meaningful once both of those have been ruled out.
judge() {
  local t="$1" ex="$2" mx="$3" la="$4" b="$5"
  case "$t" in ''|*[!0-9]*) echo "BROKEN the profiler reported no numeric TOTAL ('$t'); a tracer that produced nothing is not a validator that forked nothing"; return ;; esac
  case "$b" in ''|*[!0-9]*) echo "BROKEN no numeric FORK_BUDGET ('$b')"; return ;; esac
  # A1 floor
  if [ "$t" -le 5000 ]; then
    echo "BROKEN measured $t fork(s), at or below the 5000 floor. That is a broken tracer, an unmatched marker or a validator that exited early -- not a fast validator. An unbounded-below gate reads a dead subject as an infinitely fast one."
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
if [ "$P_POS" != "50" ] || [ "$P_NEG" != "0" ]; then
  note "FIXTURE BROKEN: self-probe returned PROBEPOS=$P_POS PROBENEG=$P_NEG; must be 50 and 0."
  exit 1
fi
note "ok    A0 self-probe   -- a known-50 script counts 50, a fork-free one counts 0"

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
    note "ok    A1 floor       -- $T1 forks is above the 5000 broken-tracer floor"
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
# that emits nothing? It must not.
printf '%s\n' '#!/usr/bin/env bash' 'x=1' 'exit 0' > "$TMP/tiny.sh"
if bash "$PROFILER" --target "$TMP/tiny.sh" --section total > "$TMP/m0.out" 2>&1; then
  m0_v="$(judge "$(field "$TMP/m0.out" TOTAL)" "$(field "$TMP/m0.out" EXIT)" \
                "$(field "$TMP/m0.out" MAXLINE)" "$(field "$TMP/m0.out" LASTARM)" "$BUDGET")"
  case "$m0_v" in
    BROKEN*floor*|BROKEN*5000*) note "ok    m0 empty-subject  -- a subject that forks nothing is BROKEN, not a pass" ;;
    *) note "FAIL  m0 empty-subject -- a near-forkless subject produced: $m0_v"; rc=1 ;;
  esac
else
  note "FAIL  m0 empty-subject -- the profiler could not profile a trivial script at all"; rc=1
fi

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
kill_j "m4 floor        a zero measurement"          BROKEN "floor" \
       "0" "$EX" "$MX" "$LA" "$T1"
kill_j "m5 wholeness    trace stops before the last arm" BROKEN "never reached the final arm" \
       "$T1" "$EX" "$((LA - 1))" "$LA" "$T1"
kill_j "m6 wholeness    the traced run exited non-zero" BROKEN "exited 2" \
       "$T1" "2" "$MX" "$LA" "$T1"

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

if [ "$rc" -eq 0 ]; then
  note "PASS  validator-fork-budget -- $T1 fork(s) of FORK_BUDGET=$BUDGET across $NFX fixture dirs; 6 arms green, 8/8 mutants killed"
fi
exit "$rc"
