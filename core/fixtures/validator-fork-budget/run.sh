#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# Hold scripts/validate-enforcement-map.sh to the FORK_BUDGET declared for it in fork-budget.txt.
#
# WHY THIS FIXTURE EXISTS. That script stated its own cost in a comment -- a fork count, a
# per-fork cost, and the CPU-seconds the suite pays for it. Every figure was true when
# written, nothing read the sentence, and by the time anyone re-measured it was several times
# low while reading exactly like a fresh measurement. The budget is now a line of code
# (`FORK_BUDGET=` in fork-budget.txt at the repo root) and this is its reader. A prose number decays silently; a
# gated one decays into a failed push.
#
# WHY FORK COUNT AND NOT WALL CLOCK. The rejection is recorded in scripts/validate-enforcement-map.sh,
# in the raise history above the fork-budget.txt pointer, and
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
#   A2  wholeness    the classifier read every trace record: TRACELINES equals MARKERS, a second
#                    reader over the same trace; a gap is BROKEN, never a red
#   A1  floor        a measurement at or below what a BROKEN subject measures, profiled live
#   A5  wholeness    the traced run exited 0 and reached past the LAST arm header's line
#   A3  ceiling      measured <= FORK_BUDGET
#   A3b headroom     measured + HEADROOM_MARGIN <= FORK_BUDGET: the window between "headroom gone"
#                    and A3's red, which A3 alone cannot see. It FAILS, never warns, because a
#                    passing fixture's stdout is hidden by the hook
#   A4  stale-high   measured >= 70% of FORK_BUDGET, or the budget has ratcheted out of reach
#   A6  BL-898       receipt-bl898.sh against the shipped validator: I83/I84's grep count does not
#                    move with the corpus, an unreadable corpus file errs, and the validator is not
#                    its own `stories_dir` reader
#   A7  BL-981       receipt-bl981.sh, the closing guard: exit 0 with a `CELL rv PASS` and a
#                    `CELL em PASS` line, anything else red, and exit 9 is FIXTURE BROKEN
#
# A1 AND A5 ARE THE TWO THAT MAKE THE OTHERS MEAN ANYTHING. A validator that dies at line 400
# forks almost nothing and sails under any ceiling; an unbounded-below gate reads that as an
# infinitely fast validator and prints the same green line it prints for a healthy one.
#
# Exit 0 iff every arm is green.
#
# Usage: run.sh
set -u
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

if [ "${1:-}" != "" ]; then echo "validator-fork-budget: usage: run.sh" >&2; exit 2; fi

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
echo "HERMETIC-CONSUMED scripts/fork-profile.sh"
VAL="$REPO/scripts/validate-enforcement-map.sh"
[ -f "$VAL" ] || { echo "FIXTURE ERROR: missing $VAL" >&2; exit 2; }
echo "HERMETIC-CONSUMED scripts/validate-enforcement-map.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
note() { printf '%s\n' "$*"; }
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
MUT_LIB="$DIR/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# --- the budget, read from the ONE line that declares it ---------------------------------
# ANCHORED AT COLUMN 0 AND COUNTED. A whole-file grep for `FORK_BUDGET` is satisfied by the
# paragraph above the assignment, and a paragraph is not a value. Exactly one declaring line
# must exist: zero means the declaration moved and this fixture would be judging against an
# empty string, two means a reader elsewhere could take the other one.
BUDGET_FILE="$REPO/fork-budget.txt"
[ -f "$BUDGET_FILE" ] || { echo "FIXTURE ERROR: missing $BUDGET_FILE" >&2; exit 2; }
echo "HERMETIC-CONSUMED fork-budget.txt"
BUDGET_LINES="$(grep -cE '^FORK_BUDGET=[0-9]+$' "$BUDGET_FILE")"
if [ "$BUDGET_LINES" -ne 1 ]; then
  note "FIXTURE BROKEN: $BUDGET_FILE declares $BUDGET_LINES line(s) matching '^FORK_BUDGET=<n>$'; exactly 1 is required."
  exit 1
fi
BUDGET="$(sed -n 's/^FORK_BUDGET=\([0-9][0-9]*\)$/\1/p' "$BUDGET_FILE")"

# Corpus size, reported alongside the absolute number so that a future reading can tell
# CORPUS GROWTH from an algorithmic regression. It is deliberately NOT a divisor: a
# forks-per-fixture ratio absorbs a regression silently as the suite grows, which is exactly
# how the prose figure this gate replaces came to be several times low.
FXROOT="$REPO/core/fixtures"
[ -d "$FXROOT" ] || FXROOT="$REPO/tests/fixtures"
NFX="$(find "$FXROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -c .)"

# --- A3b's margin, declared ONCE ---------------------------------------------------------
# BL-616 made the reading exact (A2 asserts equality across runs), so this margin is not jitter
# allowance; it is one release of warning before A3 goes red. A3 alone is silent from "headroom
# gone" until the first push that reads one fork over, and the push that spends the last of the
# headroom then fails on a change that looks like any other.
# Measured: fork-profile TOTAL read the same count in 5 of 5 interleaved base/tip reps (spread 0), so
# no part of the margin covers noise. 2 is policy: the smallest margin that still warns one release
# ahead of A3, chosen against a deterministic count and not fitted to the headroom left.
# It must stay under 30% of the budget, or A3b would meet A4's window; the A3b reachability check below asserts that.
# False-positive set, replayed over the WHOLE recorded history: 65 paragraphs that set or re-confirm the
# budget (63 in the validator's history above its pointer, 2 in fork-budget.txt; the count is checked
# against a second, independent grep of the openers), each paired with the reading it was set from.
# 61 pair by script and the other 4 by their own text. A3b fires on 2 of 65, and both are enumerated:
# v0.436.0 set 7195 on a reading of 7195 and v0.442.0 set 7196 on 7196. Each set the budget at the
# spread top on purpose, back when the reading still had a spread. Under A3b those two releases
# take 2 more. The other 63 leave headroom 3 or more; 44 of them use the usual 6 and the last 8 use 4.
# A first replay read only the 25 "RAISED TO" paragraphs and took its control from the same window,
# so it reported 0 fires; its blindness to the older states is why the control is independent now.
# The committed assignment history (first-parent, origin/main) has 72 distinct values. 8 of them have
# no paragraph and no recorded reading, so they are OUTSIDE this replay, not quiet in it: 7000 d4fd318c,
# 7050 f7318db0, 7060 727ddc6c, 7177 3bde1ca9, 7192 81443020, 6431 5fb543b3, 3261 8f177ba7,
# 3405 f4ca6764 (value, then the last commit that carried it). A3b fires on a state that spent the
# margin since the last raise. That is BL-608's motivating state: 0.796.0 read 3362-3363 against 3363,
# headroom 0-1.
HEADROOM_MARGIN=2

# --- judge: the whole verdict, one implementation -----------------------------------------
# judge <total> <exit> <maxline> <lastarm> <budget> -> "PASS" | "RED <why>" | "BROKEN <why>"
# Reads the global `$FLOOR`, which is profiled live below before the first call.
# Arm order is the order in the header and it is load-bearing: a subject that died early is
# caught by A1 when it died at the top and by A5 when it died anywhere else, and A3/A4 are
# only meaningful once both of those have been ruled out -- which is why A5 now runs BEFORE
# them. With the floor near zero, a validator that dies after a few hundred forks passes A1;
# evaluated after A4 it read "stale-high, lower the budget", a broken subject with a remedy
# that would ratchet the budget onto it. A3b sits between A3 and A4: after A3 so an over-budget
# reading keeps A3's message, before A4 because the two windows are disjoint by construction
# (`t > b - margin` against `t*10 < b*7`) and the A3b reachability check below asserts it.
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
  # as `BROKEN ... a broken tracer, an unmatched marker or a validator that exited early`.
  #
  # Second, and silently, it took A4 WITH IT. A4 fires only when `t*10 < b*7`, so with a
  # constant floor it needs `5000 < t < 0.7*b`, which is EMPTY for every budget at or below
  # 7143. Measured across the budgets this file has actually carried: b=8225 (0.583.0) left a
  # window of 5001..5756; b=6431 (0.587.0) left NONE. So A4 -- the arm whose whole subject is
  # "a ceiling nothing can reach reads exactly like one that passed" -- had itself become a
  # check that could not fire, one release before this one, and nothing said so.
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
  # refuses first, so it cannot contribute a number. A deeper truncation reads hundreds or
  # thousands of forks and is not this arm's subject: it exits non-zero or stops short of the
  # last arm, and A5 refuses it.
  #
  # A4's window is `FLOOR < t < 0.7b`, non-empty for every budget above 10*FLOOR/7 -- a
  # handful of forks today. The A4 reachability check below fails the push when a floor rises
  # to meet the ceiling, rather than silencing A4.
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
    echo "RED measured $t fork(s) against FORK_BUDGET=$b ($((t - b)) over). Across $NFX fixture directories that is $((t / (NFX > 0 ? NFX : 1))) fork(s) per fixture. The suite runs this validator well over a hundred times per full push, so this is a change to the suite's wall clock. Either remove the forks (scripts/fork-profile.sh --section by-line names the sites) or raise FORK_BUDGET in $BUDGET_FILE as a deliberate one-line diff."
    return
  fi
  # A3b headroom -- after A3 so a reading over the budget keeps A3's message, before A4 so the
  # two windows (t > b - margin, t*10 < b*7) are evaluated in the order that keeps them disjoint.
  if [ "$((t + ${HEADROOM_MARGIN:-0}))" -gt "$b" ]; then
    echo "RED headroom: measured $t fork(s) of FORK_BUDGET=$b leaves $((b - t)), under the margin of ${HEADROOM_MARGIN:-0}. The next change that adds a fork turns A3 red on an unrelated push. Re-measure with scripts/fork-profile.sh and raise FORK_BUDGET in $BUDGET_FILE by that measurement, as a one-line diff with the measurement in a comment above it."
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

# --- A2's predicate, factored out -----------------------------------------------------------
# marker_verdict <tracelines> <markers> <displaced> -> "OK" | "BROKEN <why>"
marker_verdict() {
  case "${3:-}" in ''|*[!0-9]*)
    echo "BROKEN the profiler reported no numeric DISPLACED ('${3:-}')"; return ;;
  esac
  if [ "$3" -gt 0 ]; then
    echo "BROKEN $3 trace record(s) carry no command word: a sibling record landed between a host's marker and its first word, so the host's command sits on a line with no marker and was not counted. Both readers agree on that shape, which is why it is counted on its own. Fix the classifier in scripts/fork-profile.sh, never the budget."
    return
  fi
  case "${1:-}" in ''|*[!0-9]*)
    echo "BROKEN the profiler reported no numeric TRACELINES ('${1:-}')"; return ;;
  esac
  case "${2:-}" in ''|*[!0-9]*)
    echo "BROKEN the profiler reported no numeric MARKERS ('${2:-}'). Without the second reader a skipped trace record reads as a validator that forked less."
    return ;;
  esac
  if [ "$1" -ne "$2" ]; then
    echo "BROKEN the classifier read $1 trace record(s) but the trace carries $2 marker(s) -- a gap of $(( $2 - $1 )). A record the classifier skipped is a fork it did not count, so the total is a floor of unknown depth. A new splice or marker shape has appeared; fix the classifier in scripts/fork-profile.sh, never the budget."
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
# NECESSITY: the profiler's own self-probe is the only source of PROBEPOS, PROBENEG and PROBEASG, and A0 asserts those
# three readings rather than recomputing them; no cheaper call produces them. One invocation, as before.
if ! FXCELL=fp-probe bash "$PROFILER" --probe-only > "$TMP/probe.out" 2>"$TMP/probe.err"; then
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
ok "A0 self-probe   -- a known-50 script counts 50, a fork-free one counts 0, the assignment probe counts only its 3 near-misses"

# ==========================================================================================
# THE FLOOR -- what a BROKEN subject reads under THIS profiler, measured before the corpus.
# `judge`'s A1 explains why it is a measurement and not a fraction. The subject is a script that
# runs almost nothing; it must yield a numeric TOTAL, since a floor taken from a profile that
# produced none is a floor of zero by accident.
# ==========================================================================================
printf '%s\n' '#!/usr/bin/env bash' 'x=1' 'exit 0' > "$TMP/tiny.sh"
FLOOR=""
# NECESSITY: A1's floor is what a broken subject reads under THIS profiler in THIS run, so it is profiled here, once.
for fs in tiny:"$TMP/tiny.sh"; do
  fs_name="${fs%%:*}"; fs_path="${fs#*:}"
  if ! FXCELL="fp-floor-$fs_name" bash "$PROFILER" --target "$fs_path" --section total > "$TMP/floor-$fs_name.out" 2>"$TMP/floor-$fs_name.err"; then
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

# ==========================================================================================
# THE CORPUS -- ONE reading of the real validator, checked against itself by A2.
# ==========================================================================================
# NECESSITY: this ONE reading of the real validator supplies the total, exit, highest line and last-arm line that
# the live verdict judges; no cheaper call yields a real
# total, and a second reading would add nothing because A2 proves the one reading exact. It is 31 of the fixture's
# 32 seconds and is the subject itself, so it stays at exactly one invocation.
if ! FXCELL=fp-corpus bash "$PROFILER" --section total > "$TMP/r1.out" 2>"$TMP/r1.err"; then
  note "FIXTURE BROKEN: the profiler could not produce a reading of the real validator."
  sed 's/^/      /' "$TMP/r1.err" | head -5
  exit 1
fi

T1="$(field "$TMP/r1.out" TOTAL)"
EX="$(field "$TMP/r1.out" EXIT)"
MX="$(field "$TMP/r1.out" MAXLINE)"
LA="$(field "$TMP/r1.out" LASTARM)"
N_TRACE="$(field "$TMP/r1.out" TRACELINES)"
N_MARK="$(field "$TMP/r1.out" MARKERS)"
N_DISP="$(field "$TMP/r1.out" DISPLACED)"

# --- A2 wholeness of the READING ----------------------------------------------------------
# A GAP IS BROKEN, NEVER RED. Fork count is a property of the program, not of the box; an
# instrument that skipped a record must never be reported as a regression in the change under
# test, because that is how a gate earns a reputation for lying and gets pushed past.
#
# IT REPLACES A REPEAT REQUIREMENT, AND IS STRICTER. Readings of one tree used to differ by up to
# five forks under load, and this arm demanded a total seen twice -- which failed as FIXTURE
# BROKEN at the gate's own pool load. Measured: nothing was lost; pipeline siblings' records were
# SPLICED into long host lines on the shared fd 2 and the classifier read only field 1. Every
# marker is now read, so one reading is exact, and the equality of two readers over that ONE trace
# is what proves it. Two readings could miss one shape identically and agree; this cannot.
A2V="$(marker_verdict "${N_TRACE:-}" "${N_MARK:-}" "${N_DISP:-}")"
if [ "$A2V" != "OK" ]; then
  note "FIXTURE BROKEN: ${A2V#BROKEN }"
  exit 1
fi
ok "A2 wholeness    -- the classifier read all $N_MARK trace record(s) of one reading, $N_DISP displaced"

VERDICT="$(judge "$T1" "$EX" "$MX" "$LA" "$BUDGET")"
case "$VERDICT" in
  PASS)
    ok "A1 floor       -- $T1 forks is above the broken-subject floor of $FLOOR (the most a broken subject read this run)"
    ok "A3 ceiling     -- $T1 <= FORK_BUDGET=$BUDGET ($((BUDGET - T1)) of headroom, $NFX fixture dirs)"
    ok "A3b spare      -- $((BUDGET - T1)) fork(s) to spare, at least the allowance of $HEADROOM_MARGIN"
    ok "A4 stale-high  -- $T1 is at least 70% of $BUDGET, so the ceiling is still reachable"
    ok "A5 wholeness   -- traced run exited $EX and reached line $MX, past the last arm header at $LA"
    ;;
  *)
    bad "validator-fork-budget -- ${VERDICT}"
    ;;
esac

# ==========================================================================================
# A3b AND A4 MUST BE REACHABLE AT THE COMMITTED BUDGET.
# ==========================================================================================
# A4 IS REACHABLE AT THE COMMITTED BUDGET. A1 and A4 bound `t` from opposite sides, so whether A4 has any window at all is
# a property of the FLOOR and the BUDGET together: with a floor that meets the ceiling, the arm whose subject is "a ceiling
# nothing can reach reads exactly like one that passed" would itself be a check that cannot fire. The midpoint of A4's
# window at the LIVE budget must lie inside it.
M8_LO="$FLOOR"
M8_HI="$((BUDGET * 7 / 10))"
M8_T="$(( (M8_LO + M8_HI) / 2 ))"
if [ "$M8_LO" -lt "$M8_HI" ] && [ "$M8_T" -gt "$M8_LO" ] && [ "$M8_T" -lt "$M8_HI" ]; then
  ok "A4 reachable -- a total of $M8_T lies inside A4's window ($M8_LO to $M8_HI) at FORK_BUDGET=$BUDGET"
else
  bad "A4 reachable -- A4 has NO window at FORK_BUDGET=$BUDGET (floor $M8_LO, stale-high below $M8_HI). The stale-high arm cannot fire for any measurement whatsoever, and a check that cannot fire reads exactly like one that passed."
fi

# A3b's window is `t > b - margin` and A4's is `t*10 < b*7`; they are disjoint iff `b - margin >= b*7/10`. A total one
# fork inside the margin (`b - margin + 1`) must be a reachable A3b input at the committed budget, outside A4's window, so
# a margin that grows into A4's window fails the push rather than silently shadowing A4.
M15_T="$((BUDGET - HEADROOM_MARGIN + 1))"
if [ "$M15_T" -gt "$FLOOR" ] && [ "$M15_T" -le "$BUDGET" ] \
   && [ "$((BUDGET - HEADROOM_MARGIN))" -ge "$((BUDGET * 7 / 10))" ]; then
  ok "A3b reachable -- a total of $M15_T is inside the margin of $HEADROOM_MARGIN at FORK_BUDGET=$BUDGET and outside A4's window"
else
  bad "A3b reachable -- total $M15_T (budget $BUDGET, margin $HEADROOM_MARGIN, floor $FLOOR) is not a reachable A3b input disjoint from A4's window"
fi

# ==========================================================================================
# A6 -- BL-898's RECEIPT, against the SHIPPED validator. I83 and I84 read their corpus with one grep
# per predicate, so a corpus file added under scripts/ costs no grep (`count`, with `control`
# proving the added files are in the corpus); a mode-000 corpus file is an error in both arms
# (`unread`); and the validator does not score itself a reader of `stories_dir` (`selfreader`).
# The receipt builds ONE scratch copy and prints a `CELL <name> PASS|FAIL` line per cell; its exit
# 9 is a refusal to measure, scored here as FIXTURE BROKEN rather than as a red.
# ==========================================================================================
RCPT="$DIR/receipt-bl898.sh"
[ -f "$RCPT" ] || { echo "FIXTURE ERROR: missing $RCPT" >&2; exit 2; }
# NECESSITY: the receipt runs the validator once per distinct world (unseeded, K plain files, K restating files,
# a mode-000 file, readers stripped); no cheaper call shows a fork count that does not move with the corpus. Each
# world runs in process (vem_entry); only the two cli cells start the validator as a program.
bash "$RCPT" "$VAL" > "$TMP/rcpt.out" 2>"$TMP/rcpt.err"; rcpt_rc=$?
if [ "$rcpt_rc" = 0 ] && [ "$(grep -c '^CELL [a-z]* PASS' "$TMP/rcpt.out")" = 5 ]; then
  ok "A6 BL-898      -- $(grep '^CELL count ' "$TMP/rcpt.out" | cut -d' ' -f4-); the unread and self-reader cells pass"
elif [ "$rcpt_rc" = 9 ]; then
  bad "FIXTURE BROKEN: receipt-bl898.sh refused to measure: $(head -1 "$TMP/rcpt.err")"
else
  bad "A6 BL-898 -- receipt-bl898.sh exited $rcpt_rc against the shipped validator: $(grep '^CELL [a-z]* FAIL' "$TMP/rcpt.out" | head -2 | tr '\n' ' ')"
fi
# THE TWO CLI CELLS' EQUIVALENCE. The receipt runs the validator in process; its full run also starts it as a program
# on the clean world (exit 0) and the unread world (exit 1), and both must answer as the in-process run did.
if [ "$(grep -c '^EQUIV bl898-cli-pass same exit 0$' "$TMP/rcpt.out")" = 1 ] && [ "$(grep -c '^EQUIV bl898-cli-refuse same exit 1$' "$TMP/rcpt.out")" = 1 ]; then
  ok "A6 equivalence -- the validator in process and as a program answer byte-identically (stdout, stderr, exit, grep execs) on the clean world, exit 0, and the unread world, exit 1"
else
  bad "A6 equivalence -- the in-process and command-line runs differ or did not run: $(grep '^EQUIV ' "$TMP/rcpt.out" | tr '\n' ' ')"
fi

# ==========================================================================================
# A7 -- BL-981's RECEIPT, as the CLOSING GUARD. It counts git starts from GIT_TRACE2_EVENT:
# release-version's arm_ab per commit in a scratch repository, and this validator's `--arms I14` run
# against this tree. Once BL-981 rotates its receipt is archived and inert, so this arm is what keeps
# either per-item cost from regrowing: it requires exit 0 AND a `CELL rv PASS` line AND a `CELL em PASS`
# line, and anything else is red. Exit 9 is a refusal to measure: FIXTURE BROKEN.
# ==========================================================================================
RCPT981="$DIR/receipt-bl981.sh"
[ -f "$RCPT981" ] || { echo "FIXTURE ERROR: missing $RCPT981" >&2; exit 2; }
# NECESSITY: one `--arms I14` run of the validator is the only call that shows I14's per-hook git starts.
R981_TAG=bl981 R981_EQUIV=1 bash "$DIR/receipt-bl981.sh" > "$TMP/r981.out" 2>"$TMP/r981.err"; r981_rc=$?
# a7_verdict <receipt exit> <receipt stdout> -> OK | BROKEN | RED <why>. A7's whole condition, one implementation.
a7_verdict() {
  local rvp emp cells
  rvp="$(grep -c '^CELL rv PASS ' "$2")" || rvp=0
  emp="$(grep -c '^CELL em PASS ' "$2")" || emp=0
  cells="$(grep -cE '^CELL (rv|em) (PASS|FAIL) ' "$2")" || cells=0
  if [ "$1" = 9 ]; then echo BROKEN
  elif [ "$1" = 0 ] && [ "$rvp" = 1 ] && [ "$emp" = 1 ]; then echo OK
  else echo "RED exit $1, rv PASS x$rvp, em PASS x$emp, $cells of 2 CELL lines"; fi
}
r981_v="$(a7_verdict "$r981_rc" "$TMP/r981.out")"
case "$r981_v" in
  BROKEN) bad "FIXTURE BROKEN: receipt-bl981.sh refused to measure: $(head -1 "$TMP/r981.err")" ;;
  OK) ok "A7 BL-981      -- receipt exit 0: $(grep '^CELL ' "$TMP/r981.out" | cut -d' ' -f2-3 | tr '\n' ' ')" ;;
  *) bad "A7 BL-981 -- receipt-bl981.sh ${r981_v#RED } (exit 0 and one PASS of each owed): $(grep '^CELL ' "$TMP/r981.out" | tr '\n' ' ')$(head -c 400 "$TMP/r981.err" | tr '\n' ' ')" ;;
esac
# THE TWO BL-981 CLI CELLS' EQUIVALENCE (cells.decl bl981-em, bl981-emp): the receipt's live run re-runs each `--arms I14`
# world in process and both must answer as the started program did. Not part of A7's verdict.
if [ "$(grep -c '^EQUIV bl981-em same exit 0$' "$TMP/r981.out")" = 1 ] && [ "$(grep -c '^EQUIV bl981-emp same exit 1$' "$TMP/r981.out")" = 1 ]; then
  ok "A7 equivalence -- the I14 validator in process and as a program answer byte-identically (stdout, stderr, exit, git starts) on the unseeded index, exit 0, and the seeded index, exit 1"
else
  bad "A7 equivalence -- the in-process and command-line I14 runs differ or did not run: $(grep '^EQUIV ' "$TMP/r981.out" | tr '\n' ' ')"
fi

note "validator-fork-budget: $T1 fork(s) of FORK_BUDGET=$BUDGET across $NFX fixture dirs"
report_end validator-fork-budget
