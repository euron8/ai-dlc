#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# suite-pole-guard — drive scripts/validate-suite-pole.sh on probe trees and prove each of
# its verdicts is reachable, discriminating, and killed by exactly one mutation.
#
# WHY THIS FIXTURE AND NOT THE FILED RECEIPT. The receipt compares 100 against 100 (pass)
# and 100 against 1000 (fail). FOUR wrong implementations satisfy that pair — a hardcoded
# threshold, a zero-tolerance compare, a `cmp`, and floor instead of ceiling arithmetic —
# and every one of them is silent rather than loud, which is the failure mode this repo
# names most often. The seeds that separate them cannot be written as a same-vs-same
# receipt: 105 against 100 at band 15 kills zero-tolerance, 5 against 4 kills floor, 9
# against 7 kills round. This file is the discriminating channel; the receipt is an anchor.
#
# WHY EVERY ARM DRIVES THE SHIPPING SCRIPT. A probe that re-implements the ceiling is a
# second opinion whose bugs nobody finds. Each arm below runs the real program with
# explicit `--durations`/`--baseline`/`--root` against a tree built under `mktemp -d`, and
# reads its EXIT CODE and its OUTPUT TEXT — the two things the pre-push step consumes.
#
# WHAT THIS FIXTURE CANNOT SEE, stated so nothing reads it as coverage. It cannot observe
# that the number in docs/suite-pole-baseline.tsv is the TRUE loaded pole of this suite:
# that is a calibration, taken by running the gate, and no assertion here can stand in for
# it. What the real-tree arms establish is that the tracked baseline PARSES under the
# shipping grammar and names a fixture directory that exists — the two ways a tracked file
# rots green while every probe-tree arm stays happy.
#
# Usage: run.sh [path-to-validate-suite-pole.sh]
# Exit:  0 = every assertion holds, 1 = an arm regressed, 2 = the fixture could not run.
set -uo pipefail

# The gate inherits every AI_DLC_* tunable a consumer set in settings.json, and this
# fixture's decoy arm TURNS ON AI_DLC_POLE_BASELINE deliberately. An operator carrying one
# in their environment would otherwise silently redirect every other arm's baseline.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# RESOLVE THE ROOT BY WALKING UP FOR THE SUBJECT ITSELF, never by counting `..` hops: a hop
# count answers differently from the repo root, from a subdirectory and from a sandbox copy,
# and the sandbox answer is the silent one. The marker is `scripts/validate-suite-pole.sh`
# and not `VERSION`: VERSION is in the content key's EXCLUDE set, and I55 arm 3 refuses a
# fixture that names an excluded path at the distribution root, because such a fixture's
# input can change without the suite re-running. This fixture is `.dist-only`, so there is
# no second install layout to name — the subject exists in this tree or nowhere.
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/validate-suite-pole.sh" ]; do ROOT="$(dirname "$ROOT")"; done

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
# A PRECONDITION FAILURE IS NEVER A SILENT PASS. Every arm below reads the subject's output,
# so a run that cannot invoke it produces nothing — and "nothing" scores green on any arm
# phrased as an absence. Refuse loudly instead.
broken() { printf '  FIXTURE BROKEN: %s\n' "$1" >&2; echo "suite-pole-guard: FIXTURE BROKEN" >&2; exit 2; }

echo "suite-pole-guard:"

V="${1:-$ROOT/scripts/validate-suite-pole.sh}"
[ -f "$V" ] || broken "cannot locate validate-suite-pole.sh at $V"
# PRINT THE RESOLVED SUBJECT. A mutation applied to a copy the run never loads leaves every
# arm green, which reads exactly like an arm that cannot fire.
echo "  subject: ${V#"$ROOT"/}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/suite-pole-guard.XXXXXX")" || broken "mktemp -d failed"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------------------
# PROBE TREES. A tree is a root carrying VERSION and N fixture directories each holding a
# run.sh, which is the population the subject counts for its partial-dispatch precondition.
# `--root` then gives an arm a CONTROLLED fixture count with no relation to this repo's.
# ---------------------------------------------------------------------------------------
mktree() { # <dir> <n-fixtures>
  local t="$1" n="$2" i=1
  mkdir -p "$t/core/fixtures" "$t/docs" || return 1
  printf '0.0.0\n' > "$t/VERSION" || return 1
  while [ "$i" -le "$n" ]; do
    mkdir -p "$t/core/fixtures/fx$i" || return 1
    printf '#!/usr/bin/env bash\nexit 0\n' > "$t/core/fixtures/fx$i/run.sh" || return 1
    i=$((i + 1))
  done
  return 0
}

# A durations file with one row per fixture of the tree, the named one carrying the pole
# figure. Full-length by construction, so the partial-dispatch precondition passes and the
# comparison arm is REACHED — a file one row short skips, and a skip scores green on any
# arm that only reads an exit code.
mkdur() { # <file> <n-fixtures> <pole-name> <pole-seconds>
  local f="$1" n="$2" name="$3" secs="$4" i=1
  : > "$f" || return 1
  while [ "$i" -le "$n" ]; do
    if [ "fx$i" = "$name" ]; then printf '%s %s\n' "$name" "$secs" >> "$f"
    else printf 'fx%s 1\n' "$i" >> "$f"; fi
    i=$((i + 1))
  done
  grep -qF -- "$name $secs" "$f" || return 1
  cp "$f" "$f.rec" || return 1
  return 0
}

# ---------------------------------------------------------------------------------------
# THE REAL-SHAPED WORLD. 227 fixture directories, the population the suite had when the
# row-count predicate was measured skipping nearly every push. Built ONCE and shared READ-ONLY
# as `--root` by every arm that needs it: those arms write their seeds under their own `$w`,
# never under the template, so sharing it costs no isolation, and run_arms re-runs every arm for
# every mutant -- a per-arm copy of 227 directories was the bulk of this fixture's wall clock.
#
# Costs: fx100 is the baseline pole; seven units are the ones a content-key dispatch leaves out
# -- deliberately NOT the first seven, so a reader keyed on the head of the list cannot pass --
# costing W=16 between them; the other 219 cost 12294 (218 at 56, fx2 at 86).
# ---------------------------------------------------------------------------------------
BIG_N=227
BIG_MISSING='^fx(50|80|110|140|170|200|226) '
big_rows() { # <pole-secs> [<fx2-secs>] -> all 227 rows, as the hook's merged record holds them
  awk -v p="$1" -v two="${2:-86}" 'BEGIN { for (i = 1; i <= 227; i++) {
    if (i == 100) c = p
    else if (i == 50 || i == 80 || i == 110 || i == 140 || i == 170) c = 2
    else if (i == 200 || i == 226) c = 3
    else if (i == 2) c = two
    else c = 56
    print "fx" i, c } }'
}
TPL=""

mkbase() { # <file> <pole-name> <secs> <band> <jobs> <fixtures>
  printf '# a prose comment the parser ignores\n# band: %s\n# jobs: %s\n# fixtures: %s\n%s %s\n' \
    "$4" "$5" "$6" "$2" "$3" > "$1"
}

# DRIVE. Captures stdout and stderr together, because the subject writes its PASS/SKIP lines
# to stdout and its refusals to stderr, and an arm asserting on text must see both in the
# order they were emitted.
#
# IT SETS TWO GLOBALS AND IS NEVER CALLED INSIDE A COMMAND SUBSTITUTION. The first spelling
# returned the output on stdout and set `RC` beside it, so every call site captured it — and
# an assignment made inside a command substitution is LOST to the subshell. `RC` stayed at its
# initial 0 for the whole run: every arm expecting a refusal or a growth exit read 0, NINE
# arms failed at once, and the unmutated control failed with them, which is the only reason
# this was visible rather than a battery certifying a subject it never judged.
#
# THE CUMULATIVE RECORD RIDES BESIDE THE DURATIONS FILE. `mkdur` writes `<file>.rec` holding the
# same rows, which is what the hook's merge produces after a run that dispatched every unit, and
# `drive` passes it as `--record` unless the arm named one itself. Arms about coverage write their
# own record and pass it explicitly; every other arm is a full dispatch and reads 100%.
RC=0
OUT=""
drive() { # <args...> -> output in $OUT, exit code in $RC
  local a prev="" dur="" has_rec=0
  for a in "$@"; do
    [ "$prev" = "--durations" ] && dur="$a"
    [ "$a" = "--record" ] && has_rec=1
    prev="$a"
  done
  if [ "$has_rec" -eq 0 ] && [ -n "$dur" ] && [ -f "$dur.rec" ]; then
    OUT="$(bash "$SUBJ" "$@" --record "$dur.rec" 2>&1)"; RC=$?
  else
    OUT="$(bash "$SUBJ" "$@" 2>&1)"; RC=$?
  fi
}

SUBJ="$V"

# ---------------------------------------------------------------------------------------
# THE ARMS, as functions returning 0 when the property HOLDS, so the mutant harness can run
# the identical set against a mutated copy and name the ONE arm that must move.
#
# EVERY ARM IS PRESENCE-SHAPED — each demands a specific exit code AND a specific string in
# the output. A subject replaced by `exit 0` fails them by construction rather than passing
# as a clean run, which is what stops silence scoring as a kill.
# ---------------------------------------------------------------------------------------

# grown beyond band -> exit 1 and the output NAMES the figure. The figure is what makes the
# message actionable; an arm reading only the exit code passes a guard that reports growth
# without saying how much, which is the filed receipt's own requirement.
arm_grown() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF '1000' <<<"$out" || return 1
  grep -qF 'GROWN' <<<"$out" || return 1
}

# equal -> 0. The trivial direction, and the ONLY one a cmp-style implementation gets right;
# it is here so the within-band arm beside it has a partner that separates the two.
arm_equal() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pole fx1 100s' <<<"$out" || return 1
}

# WITHIN the band -> 0. THE SEED THAT KILLS ZERO TOLERANCE, and the one the filed receipt
# structurally cannot carry.
arm_within_band() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 105 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pole fx1 105s' <<<"$out" || return 1
  # AND IT MUST NOT REPORT GROWTH IN WORDS WHILE EXITING 0. A guard that prints the FAIL
  # block and returns 0 is the shape an operator reads as a wedged gate.
  grep -qF 'GROWN' <<<"$out" && return 1
  return 0
}

# AT the ceiling (115 = 100 + ceil(15)) -> 0, and ceiling+1 -> 1. One property apart, in the
# same arm, because this boundary pair is the whole of what a `-gt` -> `-ge` mutation moves.
arm_ceiling_boundary() {
  local w="$1" out rc_at rc_over
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/at.tsv"   3 fx1 115 || return 1
  mkdur "$w/over.tsv" 3 fx1 116 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/at.tsv" --jobs 12; out="$OUT"; rc_at=$RC
  grep -qF 'ceiling 115s' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/over.tsv" --jobs 12; out="$OUT"; rc_over=$RC
  grep -qF '116' <<<"$out" || return 1
  [ "$rc_at" -eq 0 ] && [ "$rc_over" -eq 1 ]
}

# CEIL, AND NEITHER FLOOR NOR ROUND. Two baselines in ONE arm, and the merge is measured
# rather than tidy: B=4 band=15 gives 60/100 — floor 0, round 1, ceil 1 — and B=7 gives
# 105/100 — floor 1, round 1, ceil 2. A floor implementation moves BOTH, so two separate arms
# would both die on one mutation and the harness would report entanglement it is right to
# report. `fixture-mutants.md` says the fix is to decide which arm OWNS the case: one arm owns
# the arithmetic, and it carries both seeds because neither alone separates all three.
#
# THE PASS SIDE IS ASSERTED AS THE PRINTED CEILING, NOT AS AN EXIT CODE. Both pass seeds sit
# exactly ON their ceiling, which is also what `arm_ceiling_boundary` owns — keying this arm's
# pass side on the verdict would make every comparison mutation fail both. The printed ceiling
# is a property of the ARITHMETIC alone and moves only when the arithmetic does.
arm_ceil_arithmetic() {
  local w="$1" out rc_six rc_ten
  mktree "$w" 3 || return 1
  mkbase "$w/b4.tsv" fx1 4 15 12 3 || return 1
  mkdur "$w/five.tsv" 3 fx1 5 || return 1
  mkdur "$w/six.tsv"  3 fx1 6 || return 1
  drive --root "$w" --baseline "$w/b4.tsv" --durations "$w/five.tsv" --jobs 12; out="$OUT"
  grep -qF 'ceiling 5s' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/b4.tsv" --durations "$w/six.tsv" --jobs 12; out="$OUT"; rc_six=$RC
  grep -qF '6' <<<"$out" || return 1
  mkbase "$w/b7.tsv" fx1 7 15 12 3 || return 1
  mkdur "$w/nine.tsv" 3 fx1 9  || return 1
  mkdur "$w/ten.tsv"  3 fx1 10 || return 1
  drive --root "$w" --baseline "$w/b7.tsv" --durations "$w/nine.tsv" --jobs 12; out="$OUT"
  grep -qF 'ceiling 9s' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/b7.tsv" --durations "$w/ten.tsv" --jobs 12; out="$OUT"; rc_ten=$RC
  [ "$rc_six" -eq 1 ] && [ "$rc_ten" -eq 1 ]
}

# THE SELF-PROBE IS LOAD-BEARING, AND THIS IS THE ONLY ARM THAT CAN SEE IT.
#
# MEASURED, AND IT IS WHY THIS ARM EXISTS. Breaking the comparator alone — `-gt` to `-ge`, or
# dropping the `+ 99` — does NOT produce a wrong verdict: the subject's own self-probe catches
# it and the program exits 2 on every input, refusing to read a corpus it cannot judge. So a
# comparator mutation moves every arm at once and none of them owns it. What the probe
# contributes is exactly that conversion, from a silent wrong answer into a loud refusal, and
# the only way to observe it is to BUILD the broken comparator and assert the refusal.
#
# This arm mutates the subject it was handed, so under a mutant that short-circuits the probe
# it builds a doubly-broken copy, gets a verdict instead of a refusal, and fails. Under every
# other mutant the property is untouched.
arm_probe_catches_broken_comparator() {
  local w="$1" ge floor out rc_ge rc_floor
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/at.tsv" 3 fx1 115 || return 1
  ge="$w/ge.sh"; floor="$w/floor.sh"
  sed -e 's/\[ "$1" -gt "$c" \]/[ "$1" -ge "$c" ]/' "$SUBJ" > "$ge" || return 1
  cmp -s "$SUBJ" "$ge" && return 1          # the anchor is lost: this arm would assert nothing
  sed -e 's/+ 99) \/ 100/) \/ 100/' "$SUBJ" > "$floor" || return 1
  cmp -s "$SUBJ" "$floor" && return 1
  out="$(bash "$ge" --root "$w" --baseline "$w/base.tsv" --durations "$w/at.tsv" --jobs 12 2>&1)"; rc_ge=$?
  grep -qF 'SELF-PROBE MISS' <<<"$out" || return 1
  out="$(bash "$floor" --root "$w" --baseline "$w/base.tsv" --durations "$w/at.tsv" --jobs 12 2>&1)"; rc_floor=$?
  grep -qF 'SELF-PROBE MISS' <<<"$out" || return 1
  [ "$rc_ge" -eq 2 ] && [ "$rc_floor" -eq 2 ]
}

# THE ENV OVERRIDE, WITH A DECOY THAT GIVES THE OPPOSITE VERDICT. The filed receipt sets
# AI_DLC_POLE_BASELINE, so an implementation that ignores it satisfies the receipt by reading
# the real baseline instead — and on this probe tree the DEFAULT path is a baseline that
# passes the same durations the env one fails. A bare "the env path was used" assertion
# cannot tell the two apart; a decoy giving the opposite answer can.
arm_env_override() {
  local w="$1" out
  mktree "$w" 3 || return 1
  # The DECOY at the default location: band 15 over a baseline of 1000, which 1000 passes.
  mkbase "$w/docs/suite-pole-baseline.tsv" fx1 1000 15 12 3 || return 1
  # The env baseline: 100, which the same 1000 fails.
  mkbase "$w/env.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  # CONTROL, IN THE SAME ARM: with no env set the decoy is read and the verdict is PASS. That
  # is what proves the decoy really would have given the opposite answer, rather than the arm
  # asserting a failure the tree produces for some other reason.
  drive --root "$w" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'baseline fx1 1000s' <<<"$out" || return 1
  AI_DLC_POLE_BASELINE="$w/env.tsv" drive --root "$w" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'GROWN' <<<"$out" || return 1
}

# `--baseline` likewise, against the same decoy. The flag and the env are two delivery paths
# to one value and a program can honour either alone.
arm_baseline_flag() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkbase "$w/docs/suite-pole-baseline.tsv" fx1 1000 15 12 3 || return 1
  mkbase "$w/flag.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  drive --root "$w" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  drive --root "$w" --baseline "$w/flag.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'GROWN' <<<"$out" || return 1
}

# DURATIONS ABSENT and DURATIONS EMPTY -> 0 with SKIP. Two distinct inputs reaching the same
# verdict by different paths: a `[ ! -s ]` covers both, a `[ ! -f ]` covers only one, and the
# empty case is the one the hook produces on every red or skipped run.
arm_no_measurement() {
  local w="$1" out rc_absent rc_empty
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/nothing-here.tsv" --jobs 12; out="$OUT"; rc_absent=$RC
  grep -qF 'SKIP' <<<"$out" || return 1
  : > "$w/empty.tsv" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/empty.tsv" --jobs 12; out="$OUT"; rc_empty=$RC
  grep -qF 'SKIP' <<<"$out" || return 1
  [ "$rc_absent" -eq 0 ] && [ "$rc_empty" -eq 0 ]
}

# THE REALISTIC PARTIAL DISPATCH IS COMPARED. 220 rows against 227 directories, the seven
# missing units costing 16s of the record's 13140 -- the shape a content-key push actually
# produces, and the one the old row-count equality skipped on nearly every push. A grown pole
# FAILS; the within-band near-miss passes; and the COVERAGE FIGURE IS ASSERTED EXACTLY, because
# a predicate that divides by the wrong thing can still clear 90% and only the printed figure
# shows it: (12294 + 830) / (12294 + 830 + 16) = 99.87%.
arm_coverage_partial() {
  local w="$1" out rc_grown rc_near
  [ -d "$TPL/core/fixtures/fx227" ] || return 1
  mkbase "$w/base.tsv" fx100 830 15 12 227 || return 1
  big_rows 830  > "$w/rec830.tsv"  || return 1
  big_rows 1000 > "$w/rec1000.tsv" || return 1
  grep -vE "$BIG_MISSING" "$w/rec830.tsv"  > "$w/last830.tsv"  || return 1
  grep -vE "$BIG_MISSING" "$w/rec1000.tsv" > "$w/last1000.tsv" || return 1
  [ "$(grep -c . "$w/last1000.tsv")" -eq 220 ] || return 1
  drive --root "$TPL" --baseline "$w/base.tsv" --durations "$w/last830.tsv" --record "$w/rec830.tsv" --jobs 12; out="$OUT"; rc_near=$RC
  grep -qF 'coverage 99.87%' <<<"$out" || return 1
  grep -qF 'pole fx100 830s' <<<"$out" || return 1
  drive --root "$TPL" --baseline "$w/base.tsv" --durations "$w/last1000.tsv" --record "$w/rec1000.tsv" --jobs 12; out="$OUT"; rc_grown=$RC
  grep -qF 'GROWN' <<<"$out" || return 1
  grep -qF 'fx100 at 1000s' <<<"$out" || return 1
  [ "$rc_near" -eq 0 ] && [ "$rc_grown" -eq 1 ]
}

# A NEAR-SOLO DISPATCH SKIPS NAMING COVERAGE, EVEN WITH A GROWN POLE. Thirty units of 227, the
# pole among them at a figure far past its ceiling: that is the 442s-loaded/112s-solo shape in
# the other direction, and comparing it is the false red this guard must never produce.
#
# THE NEAR-MISS IS IN THE SAME ARM: the identical grown pole in a FULL dispatch over the same
# tree and record is compared and fails. Without it, an implementation skipping everything passes.
arm_partial_dispatch() {
  local w="$1" out rc_solo rc_full
  [ -d "$TPL/core/fixtures/fx227" ] || return 1
  mkbase "$w/base.tsv" fx100 830 15 12 227 || return 1
  big_rows 1000 > "$w/rec.tsv" || return 1
  { grep '^fx100 ' "$w/rec.tsv"; grep -v '^fx100 ' "$w/rec.tsv" | sed -n '1,29p'; } > "$w/solo.tsv" || return 1
  [ "$(grep -c . "$w/solo.tsv")" -eq 30 ] || return 1
  drive --root "$TPL" --baseline "$w/base.tsv" --durations "$w/solo.tsv" --record "$w/rec.tsv" --jobs 12; out="$OUT"; rc_solo=$RC
  grep -qF 'SKIP' <<<"$out" || return 1
  grep -qF 'coverage' <<<"$out" || return 1
  grep -qF 'below 90%' <<<"$out" || return 1
  grep -qF 'GROWN' <<<"$out" && return 1
  drive --root "$TPL" --baseline "$w/base.tsv" --durations "$w/rec.tsv" --record "$w/rec.tsv" --jobs 12; out="$OUT"; rc_full=$RC
  grep -qF 'GROWN' <<<"$out" || return 1
  [ "$rc_solo" -eq 0 ] && [ "$rc_full" -eq 1 ]
}

# A GHOST ROW IN THE RECORD IS NOT WORK THIS RUN FAILED TO DO. The hook's merge keeps a key for
# a deleted fixture forever; a 100000s ghost in the denominator would read a full dispatch as
# 12% coverage and skip a grown pole. Joined to the directories on disk, it is compared and FAILS.
#
# THE NEAR-MISS CARRIES THE SAME 100000s ON A FIXTURE THAT EXISTS and was not dispatched, which
# MUST count against coverage -- so the join is "on disk", not "present in this run".
arm_ghost_record() {
  local w="$1" out rc_ghost rc_real
  [ -d "$TPL/core/fixtures/fx227" ] || return 1
  mkbase "$w/base.tsv" fx100 830 15 12 227 || return 1
  [ -d "$TPL/core/fixtures/fx-deleted-ghost" ] && return 1
  big_rows 1000 > "$w/last.tsv" || return 1
  { cat "$w/last.tsv"; printf 'fx-deleted-ghost 100000\n'; } > "$w/rec-ghost.tsv" || return 1
  drive --root "$TPL" --baseline "$w/base.tsv" --durations "$w/last.tsv" --record "$w/rec-ghost.tsv" --jobs 12; out="$OUT"; rc_ghost=$RC
  grep -qF 'GROWN' <<<"$out" || return 1
  # The near-miss asserts the DENOMINATOR, not the verdict: 12208 + 1000 + 16 + 100000 = 113224
  # with the undispatched fx2 counted. Keyed on the verdict it would also die to the threshold
  # mutant, and keyed on the percentage to the numerator-side mutants; the near-solo arm and the
  # coverage-partial arm own those. A join on "present in this run" prints 13224 here.
  big_rows 1000 100000 > "$w/rec-real.tsv" || return 1
  grep -v '^fx2 ' "$w/rec-real.tsv" > "$w/last-real.tsv" || return 1
  drive --root "$TPL" --baseline "$w/base.tsv" --durations "$w/last-real.tsv" --record "$w/rec-real.tsv" --jobs 12; out="$OUT"; rc_real=$RC
  grep -qF '113224s' <<<"$out" || return 1
  [ "$rc_ghost" -eq 1 ] && [ "$rc_real" -ne 2 ]
}

# THE BASELINE POLE ABSENT, ASYMMETRICALLY. Within band with the watched unit not timed is a
# SKIP naming it -- before this, it printed a false-green PASS with a "pole moved" NOTE. Over the
# ceiling with the watched unit absent still FAILS: growth past the ceiling is growth whichever
# unit carries it, and absence is never an acquittal.
#
# EACH .last CARRIES A ROW FOR A FIXTURE THAT IS NOT ON DISK, so its row count equals the
# directory count. Without it, a restored row-count equality would skip this arm too and the
# arm would die to a mutant the coverage-partial arm owns.
arm_pole_absent() {
  local w="$1" out rc_within rc_over
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  printf 'fx1 5\nfx2 105\nfx3 100\n'        > "$w/rec-within.tsv" || return 1
  printf 'fx2 105\nfx3 100\nfx-gone 1\n'    > "$w/last-within.tsv" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/last-within.tsv" --record "$w/rec-within.tsv" --jobs 12; out="$OUT"; rc_within=$RC
  grep -qF 'baseline pole not dispatched' <<<"$out" || return 1
  grep -qF 'pole fx2' <<<"$out" && return 1
  printf 'fx1 5\nfx2 200\nfx3 100\n'        > "$w/rec-over.tsv" || return 1
  printf 'fx2 200\nfx3 100\nfx-gone 1\n'    > "$w/last-over.tsv" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/last-over.tsv" --record "$w/rec-over.tsv" --jobs 12; out="$OUT"; rc_over=$RC
  grep -qF 'GROWN' <<<"$out" || return 1
  grep -qF 'fx2 at 200s' <<<"$out" || return 1
  [ "$rc_within" -eq 0 ] && [ "$rc_over" -eq 1 ]
}

# NO CUMULATIVE RECORD -> SKIP BY NAME, absent and empty alike. The near-miss is the same run
# with its record present, which is compared and fails.
arm_no_record() {
  local w="$1" out rc_absent rc_empty rc_present
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --record "$w/no-record-here.tsv" --jobs 12; out="$OUT"; rc_absent=$RC
  grep -qF 'no cumulative durations record' <<<"$out" || return 1
  : > "$w/empty-rec.tsv" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --record "$w/empty-rec.tsv" --jobs 12; out="$OUT"; rc_empty=$RC
  grep -qF 'no cumulative durations record' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --record "$w/dur.tsv.rec" --jobs 12; out="$OUT"; rc_present=$RC
  grep -qF 'GROWN' <<<"$out" || return 1
  [ "$rc_absent" -eq 0 ] && [ "$rc_empty" -eq 0 ] && [ "$rc_present" -eq 1 ]
}

# ONE ROW PER POOL WIDTH. A baseline with a block at width 12 (fx1 100) and one at width 16
# (fx1 2000), driven with the same 1000s pole at three widths:
#   --jobs 16 compares against the SECOND block and passes -- the case a first-row reader fails;
#   --jobs 12 compares against the FIRST and fails -- the case a last-row reader fails;
#   --jobs 4  has no row and SKIPs naming the widths that do, at exit 0 and never a FAIL.
arm_jobs_mismatch() {
  local w="$1" out rc16 rc12 rc4
  mktree "$w" 3 || return 1
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\n# band: 15\n# jobs: 16\n# fixtures: 3\nfx1 2000\n' > "$w/base.tsv" || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 16; out="$OUT"; rc16=$RC
  grep -qF 'baseline fx1 2000s' <<<"$out" || return 1
  grep -qF 'pool 16' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc12=$RC
  grep -qF 'GROWN' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"; rc4=$RC
  grep -qF 'pool width 4 has no baseline row (widths with a row: 12 16)' <<<"$out" || return 1
  [ "$rc16" -eq 0 ] && [ "$rc12" -eq 1 ] && [ "$rc4" -eq 0 ]
}

# THE REFUSALS, all exit 2. A malformed baseline is a broken instrument, and a growth figure
# computed from one would be a number invented by a parser.
#
# EACH DIRECTIVE IS PROBED SEPARATELY. A loop over three names that checks only the first is
# a guard two thirds unable to fire, and one seed cannot tell that from a working loop.
arm_refusals() {
  local w="$1" out rc_two rc_noband rc_nojobs rc_stale
  mktree "$w" 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\nfx2 350\n' > "$w/two.tsv" || return 1
  drive --root "$w" --baseline "$w/two.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_two=$RC
  grep -qF 'in its own block' <<<"$out" || return 1
  # TWO BLOCKS FOR ONE WIDTH: refused by name, never resolved by taking the first.
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\n# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 300\n' > "$w/dupw.tsv" || return 1
  drive --root "$w" --baseline "$w/dupw.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 2 ] || return 1
  grep -qF 'second row for pool width 12' <<<"$out" || return 1
  printf '# jobs: 12\n# fixtures: 3\nfx1 100\n' > "$w/noband.tsv" || return 1
  drive --root "$w" --baseline "$w/noband.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_noband=$RC
  grep -qF 'band' <<<"$out" || return 1
  printf '# band: 15\n# fixtures: 3\nfx1 100\n' > "$w/nojobs.tsv" || return 1
  drive --root "$w" --baseline "$w/nojobs.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_nojobs=$RC
  grep -qF 'jobs' <<<"$out" || return 1
  # THE STALE POLE: a baseline naming a directory that is not under the root's core/fixtures.
  # It is a refusal and not a skip BECAUSE IT CAN NEVER SURFACE DOWNSTREAM — a deleted fixture
  # produces no durations row, so a comparison arm would skip forever and the tracked file
  # would rot green.
  mkbase "$w/stale.tsv" fx-that-was-deleted 100 15 12 3 || return 1
  drive --root "$w" --baseline "$w/stale.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_stale=$RC
  grep -qF 'fx-that-was-deleted' <<<"$out" || return 1
  # A ZERO-SECOND ROW (ceiling zero, every run reads as growth) and a band past 1000% (a ceiling
  # nothing reaches, and past the shell's integer range a negative one) are not calibrations.
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 0\n' > "$w/zero.tsv" || return 1
  drive --root "$w" --baseline "$w/zero.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 2 ] || return 1
  grep -qF 'zero seconds' <<<"$out" || return 1
  printf '# band: 1001\n# jobs: 12\n# fixtures: 3\nfx1 100\n' > "$w/hugeband.tsv" || return 1
  drive --root "$w" --baseline "$w/hugeband.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 2 ] || return 1
  grep -qF 'above 1000%' <<<"$out" || return 1
  # AN EXPLICIT EMPTY --jobs IS REFUSED, NOT DEFAULTED to 12 -- an unset "$FIXTURE_JOBS" in the
  # hook would otherwise compare against the 12-width row whatever the pool ran at.
  mkbase "$w/ok.tsv" fx1 100 15 12 3 || return 1
  drive --root "$w" --baseline "$w/ok.tsv" --durations "$w/dur.tsv" --jobs ''; out="$OUT"
  [ "$RC" -eq 2 ] || return 1
  grep -qF -- '--jobs "" is not a number' <<<"$out" || return 1
  [ "$rc_two" -eq 2 ] && [ "$rc_noband" -eq 2 ] && [ "$rc_nojobs" -eq 2 ] && [ "$rc_stale" -eq 2 ]
}

# AN ORPHANED BLOCK IS REFUSED WHEREVER IT SITS, NOT ONLY AT EOF. Three seeds, each a block left
# without its row MID-FILE, so a later directive would overwrite an earlier one and the next row
# would inherit terms nobody wrote beside it:
#   (1) a whole block at width 12 then a whole block at width 16, ONE row -- read last-wins it
#       becomes a width-16 file and --jobs 12 SKIPs with exit 0;
#   (2) a valid width-12 row, an orphan "band 50 / jobs 16", then "band 20 / fixtures" and a row
#       -- read last-wins the row compares at width 16 on band 20;
#   (3) one block carrying `# jobs: 12` AND `# jobs: 16` -- read last-wins --jobs 12 SKIPs.
# Each must exit 2 naming the repeat. The NEAR-MISS is the well-formed two-block file in
# `jobs_mismatch`, which parses.
arm_orphan_block() {
  local w="$1" out s
  mktree "$w" 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  printf '# band: 20\n# jobs: 12\n# fixtures: 3\n# band: 25\n# jobs: 16\n# fixtures: 3\nfx1 100\n' > "$w/s1.tsv" || return 1
  printf '# band: 20\n# jobs: 12\n# fixtures: 3\nfx2 999\n# band: 50\n# jobs: 16\n# band: 20\n# fixtures: 3\nfx1 100\n' > "$w/s2.tsv" || return 1
  printf '# band: 20\n# jobs: 12\n# jobs: 16\n# fixtures: 3\nfx1 100\n' > "$w/s3.tsv" || return 1
  for s in s1:12 s2:16 s3:12; do
    drive --root "$w" --baseline "$w/${s%%:*}.tsv" --durations "$w/dur.tsv" --jobs "${s#*:}"; out="$OUT"
    [ "$RC" -eq 2 ] || return 1
    grep -qF 'appears twice before a data row consumes its block' <<<"$out" || return 1
  done
  return 0
}

# THE STALE-POLE CHECK COVERS EVERY BLOCK, NOT ONLY THE ONE SELECTED. A width-16 row naming a
# deleted fixture is never compared on a width-12 push, so without this it rots until the width
# changes. The stale row is the SECOND block, so a check of the first row alone cannot see it.
# The near-miss is the same file with the second pole pointing at a real directory.
arm_stale_second_block() {
  local w="$1" out rc_stale rc_ok
  mktree "$w" 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\n# band: 15\n# jobs: 16\n# fixtures: 3\nfx-gone-at-16 100\n' > "$w/stale.tsv" || return 1
  drive --root "$w" --baseline "$w/stale.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_stale=$RC
  grep -qF 'fx-gone-at-16' <<<"$out" || return 1
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\n# band: 15\n# jobs: 16\n# fixtures: 3\nfx2 100\n' > "$w/ok.tsv" || return 1
  drive --root "$w" --baseline "$w/ok.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_ok=$RC
  grep -qF 'pole fx1 100s' <<<"$out" || return 1
  [ "$rc_stale" -eq 2 ] && [ "$rc_ok" -eq 0 ]
}

# THE OBSERVED POLE IS THIS RUN'S MAX, NEVER THE RECORD'S. The record keeps the last cost of
# every unit the content key skipped; one of those can exceed anything this run timed. Here
# fx50 (skipped) carries 1000s in the record, above fx100's 955s ceiling, while this run's max is
# fx100 at 830 and coverage is 13138/14138 -- comparable. Read from the record, a unit this run
# never timed would FAIL the push: a false red on a stale figure.
#
# THE SEED IS SHAPED SO ONLY THE POLE SOURCE CAN MOVE IT. The .last holds 227 rows -- every unit
# but fx50, plus one row for a fixture not on disk -- so a restored row-count equality still
# compares it, and the arm asserts the VERDICT rather than the coverage figure, so a mis-scaled
# divisor (still above 90%) leaves it standing. coverage_partial owns both of those.
arm_record_pole_skipped() {
  local w="$1" out
  [ -d "$TPL/core/fixtures/fx227" ] || return 1
  [ -d "$TPL/core/fixtures/fx-off-disk" ] && return 1
  mkbase "$w/base.tsv" fx100 830 15 12 227 || return 1
  big_rows 830 | awk '$1 == "fx50" { $2 = 1000 } { print }' > "$w/rec.tsv" || return 1
  { big_rows 830 | grep -v '^fx50 '; printf 'fx-off-disk 1\n'; } > "$w/last.tsv" || return 1
  grep -qF 'fx50 1000' "$w/rec.tsv" || return 1
  [ "$(grep -c . "$w/last.tsv")" -eq 227 ] || return 1
  drive --root "$TPL" --baseline "$w/base.tsv" --durations "$w/last.tsv" --record "$w/rec.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pole fx100 830s against baseline fx100 830s' <<<"$out" || return 1
  grep -qF 'GROWN' <<<"$out" && return 1
  return 0
}

# WIDTHS ARE CANONICAL INTEGERS. `# jobs: 012` is width 12: a second block at `# jobs: 12` is a
# DUPLICATE and refuses, and `--jobs 12` selects the `012` row. A CRLF-saved baseline parses
# exactly as its LF twin does. Without canonical keys the duplicate is two "widths" and the
# guard picks whichever block an awk numeric compare happens to match first.
arm_jobs_canonical() {
  local w="$1" out rc_dup rc_one rc_crlf
  mktree "$w" 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  printf '# band: 15\n# jobs: 012\n# fixtures: 3\nfx1 100\n# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 300\n' > "$w/dup.tsv" || return 1
  drive --root "$w" --baseline "$w/dup.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_dup=$RC
  grep -qF 'second row for pool width 12' <<<"$out" || return 1
  printf '# band: 15\n# jobs: 012\n# fixtures: 3\nfx1 100\n' > "$w/one.tsv" || return 1
  drive --root "$w" --baseline "$w/one.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_one=$RC
  grep -qF 'pole fx1 100s against baseline fx1 100s' <<<"$out" || return 1
  printf '# band: 15\r\n# jobs: 12\r\n# fixtures: 3\r\nfx1 100\r\n' > "$w/crlf.tsv" || return 1
  drive --root "$w" --baseline "$w/crlf.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_crlf=$RC
  grep -qF 'pole fx1 100s against baseline fx1 100s' <<<"$out" || return 1
  [ "$rc_dup" -eq 2 ] && [ "$rc_one" -eq 0 ] && [ "$rc_crlf" -eq 0 ]
}

# WIDTH SELECTION IS EXACT INTEGER EQUALITY. `--jobs 1` against rows at 12 and 16 has no row:
# a substring or regex match would select 12, and a pool of one compared against a twelve-way
# loaded figure reads as a dramatic improvement. The near-miss is `--jobs 12` selecting row 12.
arm_width_exact() {
  local w="$1" out rc1 rc12
  mktree "$w" 3 || return 1
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\n# band: 15\n# jobs: 16\n# fixtures: 3\nfx1 200\n' > "$w/base.tsv" || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 1; out="$OUT"; rc1=$RC
  grep -qF 'pool width 1 has no baseline row (widths with a row: 12 16)' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc12=$RC
  grep -qF 'pole fx1 100s against baseline fx1 100s' <<<"$out" || return 1
  [ "$rc1" -eq 0 ] && [ "$rc12" -eq 0 ]
}

# S*2 < B -> exit 0 AND the lower-the-row NOTE. THERE IS NO DOWNWARD FAIL, deliberately: a
# pole below its baseline is the outcome the guard exists to encourage, and failing on it
# would block the push that improves the suite and fire on any quiet box. The arm asserts
# BOTH halves — the note appears, and the exit is still 0.
arm_lower_the_row_note() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 1000 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'lower the row' <<<"$out" || return 1
  # THE NEAR-MISS, one property apart: a figure just OVER half the baseline gets no note and
  # still exits 0. Without it, an implementation printing the note unconditionally passes.
  mkdur "$w/near.tsv" 3 fx1 501 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/near.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'lower the row' <<<"$out" && return 1
  return 0
}

# THE POLE MOVING IS NOT GROWTH. A different fixture being longest, within band, passes and
# NAMES BOTH — a baseline pinned to a unit that is no longer longest is watching the wrong
# number while staying green, and the operator can only see that if the line says so.
arm_pole_moved() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  # fx2 is now the longest, at a figure inside fx1's band. fx1 is still DISPATCHED: a run that
  # did not time it SKIPs instead, which `pole_absent` owns.
  printf 'fx1 50\nfx2 105\nfx3 1\n' > "$w/dur.tsv" || return 1
  cp "$w/dur.tsv" "$w/dur.tsv.rec" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'NOTE' <<<"$out" || return 1
  grep -qF 'fx2' <<<"$out" || return 1
  grep -qF 'fx1' <<<"$out" || return 1
}

# THE PROBE RUNS BEFORE THE CORPUS, ASSERTED ON OUTPUT ORDER. A self-probe that runs after
# the corpus read cannot establish anything about a run the corpus refused — the program
# exits first and the probe never happens. The only observable that separates the two is
# WHICH LINE COMES FIRST when the baseline is corrupt.
arm_probe_before_corpus() {
  local w="$1" out n_probe n_refuse
  mktree "$w" 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\nfx2 350\n' > "$w/corrupt.tsv" || return 1
  drive --root "$w" --baseline "$w/corrupt.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 2 ] || return 1
  n_probe="$(printf '%s\n' "$out"  | grep -n 'probe' | sed -n 1p | cut -d: -f1)"
  n_refuse="$(printf '%s\n' "$out" | grep -n 'REFUSE' | sed -n 1p | cut -d: -f1)"
  [ -n "$n_probe" ] || return 1
  [ -n "$n_refuse" ] || return 1
  [ "$n_probe" -lt "$n_refuse" ]
}

# CWD-INVARIANCE, ASSERTED IN THE FIXTURE'S OWN ARMS. A fixture that is green only from the
# repo root may be asserting nothing, and it does not get this property from how the suite
# drives it. The same passing case is run from the repo root, from a SUBDIRECTORY of the
# probe root, and from `/` — three cwds whose walk-up for VERSION gives three different
# answers, all of which `--root` must override.
arm_cwd_invariance() {
  local w="$1" o_root o_sub o_slash r_root r_sub r_slash
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 105 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; o_root="$OUT"; r_root=$RC
  o_sub="$( cd "$w/core/fixtures/fx1" && bash "$SUBJ" --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12 --record "$w/dur.tsv.rec" 2>&1 )"; r_sub=$?
  o_slash="$( cd / && bash "$SUBJ" --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12 --record "$w/dur.tsv.rec" 2>&1 )"; r_slash=$?
  [ "$r_root" -eq 0 ] && [ "$r_sub" -eq 0 ] && [ "$r_slash" -eq 0 ] || return 1
  # IDENTICAL VERDICT, not merely three zeros: three runs that all printed nothing would be
  # three equal exits. The verdict line itself has to match, and it has to be the real one.
  grep -qF 'pole fx1 105s' <<<"$o_root" || return 1
  [ "$o_root" = "$o_sub" ] || return 1
  [ "$o_root" = "$o_slash" ] || return 1
}

ARMS="grown equal within_band ceiling_boundary ceil_arithmetic
probe_catches_broken_comparator
env_override baseline_flag no_measurement partial_dispatch jobs_mismatch refusals
lower_the_row_note pole_moved probe_before_corpus cwd_invariance
coverage_partial ghost_record pole_absent no_record
orphan_block stale_second_block record_pole_skipped jobs_canonical width_exact"

ARM_COUNT=0
for _a in $ARMS; do ARM_COUNT=$((ARM_COUNT + 1)); done

# THE 227-DIRECTORY TEMPLATE, built once and shared read-only as `--root`. Asserted here, before any arm
# reads it, so a short template is FIXTURE BROKEN rather than a coverage figure off by a unit.
TPL="$WORK/tpl227"
mktree "$TPL" "$BIG_N" || broken "could not build the $BIG_N-directory template"
[ "$(find "$TPL/core/fixtures" -mindepth 2 -maxdepth 2 -name run.sh | wc -l | tr -d ' ')" = "$BIG_N" ] \
  || broken "the template does not carry $BIG_N fixture directories"

run_arms() { # <subject> -> "<name>:<0|1>" per arm, each in its own fresh probe tree
  local subj="$1" name w rc
  local saved="$SUBJ"
  SUBJ="$subj"
  for name in $ARMS; do
    w="$(mktemp -d "$WORK/t.XXXXXX")" || { printf '%s:1\n' "$name"; continue; }
    "arm_$name" "$w" >/dev/null 2>&1 && rc=0 || rc=1
    printf '%s:%s\n' "$name" "$rc"
  done
  SUBJ="$saved"
}

LIVE="$(run_arms "$V")"
n_live="$(printf '%s\n' "$LIVE" | grep -c ':')" || n_live=0
[ "$n_live" -eq "$ARM_COUNT" ] || broken "$n_live of $ARM_COUNT arms produced a verdict — an arm that did not run prints nothing, and a short green report reads exactly like a complete one"

while IFS=: read -r name rc; do
  [ -n "$name" ] || continue
  case "$name" in
    grown)               msg="a pole grown past the band exits 1 and the output NAMES the figure" ;;
    equal)               msg="an unchanged pole exits 0 and reports the comparison" ;;
    within_band)         msg="105 against 100 at band 15 exits 0 and reports no growth (the seed a zero-tolerance implementation dies on)" ;;
    ceiling_boundary)    msg="AT the ceiling (115) passes and ceiling+1 (116) fails, one property apart" ;;
    ceil_arithmetic)     msg="the ceiling is CEIL and neither floor nor round: B=4 band=15 gives 5 (floor would give 4) and B=7 gives 9 (round would give 8)" ;;
    probe_catches_broken_comparator) msg="a comparator broken either way (-ge, or the +99 dropped) is caught by the subject's OWN self-probe and refuses at exit 2 rather than returning a wrong verdict" ;;
    env_override)        msg="AI_DLC_POLE_BASELINE is read, against a DECOY at the default path that gives the opposite verdict" ;;
    baseline_flag)       msg="--baseline is read, against the same decoy" ;;
    no_measurement)      msg="a durations file that is absent, and one that is EMPTY, each SKIP at exit 0" ;;
    partial_dispatch)    msg="a near-solo dispatch (30 of 227) with a grown pole SKIPs naming coverage below 90%, while the same pole in a full dispatch FAILS" ;;
    jobs_mismatch)       msg="one baseline row per pool width: --jobs 16 compares against the SECOND block, --jobs 12 against the first, and a width with no row SKIPs naming the widths that have one" ;;
    refusals)            msg="a row with no block of its own, two rows for one width, a missing band, a missing jobs, a pole naming no fixture directory, a zero-second row, a band over 1000%, and an empty --jobs each exit 2 and name the cause" ;;
    orphan_block)        msg="a block left without its row MID-FILE (two whole blocks, an orphan between rows, a repeated jobs line) exits 2 naming the repeat" ;;
    stale_second_block)  msg="a stale pole in the SECOND, unselected block exits 2 naming it, while the same file with a real directory there is compared" ;;
    record_pole_skipped) msg="a skipped unit costing more than the ceiling in the RECORD does not become the observed pole: this run's max (fx100 830s) is compared and passes" ;;
    jobs_canonical)      msg="'# jobs: 012' is width 12: beside a '# jobs: 12' block it is a duplicate (exit 2), alone it is selected by --jobs 12, and a CRLF baseline parses as its LF twin" ;;
    width_exact)         msg="width selection is exact: --jobs 1 against rows at 12 and 16 SKIPs naming both, while --jobs 12 selects row 12" ;;
    coverage_partial)    msg="a realistic 220-of-227 dispatch is COMPARED at coverage 99.87%: a grown pole FAILS and the within-band near-miss passes" ;;
    ghost_record)        msg="a 100000s ghost row for a deleted fixture leaves a full dispatch compared (FAIL), while the same cost on an undispatched fixture on disk is counted in the 113224s denominator" ;;
    pole_absent)         msg="the baseline pole absent: within band SKIPs 'not dispatched', above the ceiling still FAILS" ;;
    no_record)           msg="an absent and an empty cumulative record each SKIP by name, while the present record is compared and FAILS" ;;
    lower_the_row_note)  msg="a figure under half the baseline exits 0 WITH the lower-the-row NOTE, and one just over half gets no note (there is no downward FAIL)" ;;
    pole_moved)          msg="the pole moving to another fixture within band exits 0 and NAMES BOTH fixtures" ;;
    probe_before_corpus) msg="with a CORRUPT baseline the self-probe's line still precedes the refusal (asserted on output order)" ;;
    cwd_invariance)      msg="the same passing case from the repo root, from a subdirectory of the probe root, and from / gives a byte-identical verdict" ;;
    *)                   msg="$name" ;;
  esac
  [ "$rc" -eq 0 ] && ok "$msg" || bad "$msg"
done <<EOF
$LIVE
EOF

# ---------------------------------------------------------------------------------------
# THERE IS NO REAL-TREE ARM HERE, AND THAT IS I55 ARM 3'S RULING, NOT AN OMISSION. The first
# cut asserted that the TRACKED docs/suite-pole-baseline.tsv parses under the shipping
# grammar. docs/ is in the content key's EXCLUDE set, so a push editing only that file skips
# the whole suite and an arm here could never see the edit -- a reader whose input can move
# without it running. The reader that CAN see it is the pre-push step itself, which parses
# the baseline on every push, content-key hit included (it runs the guard against an empty
# durations file on a skip). Site the duty where it can fire; do not restate it here.
# ---------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------
# MUTANTS. Each is a COPY of the WHOLE scripts directory — the subject resolves no siblings
# today, but a lone one-file copy is how a battery comes to score silence as a kill the day
# it does. Each mutation is guarded three ways: the anchor's match count is PRINTED and a
# zero is reported as FIXTURE BROKEN rather than as a kill; `cmp -s` refuses a sed that
# matched nothing; and the mutant must be killed by exactly ONE named arm.
# ---------------------------------------------------------------------------------------
MUTROOT="$WORK/mut"
mkdir -p "$MUTROOT" || broken "could not create the mutant root"
SUBJ_DIR="$(dirname "$V")"
SUBJ_BASE="$(basename "$V")"
kills=0
MUT_COUNT=0
MUT_TABLE=""

# TOLERATED CO-KILLS, PER MUTANT, NAMED AND JUSTIFIED — never a blanket relaxation.
#
# `fixture-mutants.md`: two failures mean the assertions are entangled and one is vacuous,
# AND where both findings are genuinely true the arms OVERLAP rather than the mutant being
# wrong, so one of them OWNS the case and the other stands down for it. Two mutations here
# are of the second kind, measured:
#
#   probe-then-exit-0 deletes the ENTIRE corpus verdict. Every arm that reads a verdict is
#   supposed to die; an arm surviving it would be one that never reached the corpus. The
#   owning arm is `grown`, and `probe_catches_broken_comparator` is the one arm that must
#   SURVIVE — it drives its own copies and asserts a refusal the probe still produces.
#
#   downward-note-becomes-fail and partial-dispatch-compared each also move `cwd_invariance`,
#   which compares three runs of a PASSING case byte-for-byte. Any mutation that changes what
#   a passing run prints or returns necessarily moves it. It owns invariance across cwd, not
#   the verdict, so it stands down for those two.
#
# A mutant's tolerated set is declared BY NAME. An unexpected co-kill is still a FAIL, so the
# rule cannot silently widen as arms are added.
co_kills_ok() { # <label> -> the arms allowed to die beside the owner
  case "$1" in
    probe-then-exit-0)          printf '%s' "equal within_band ceiling_boundary ceil_arithmetic env_override baseline_flag no_measurement partial_dispatch jobs_mismatch refusals lower_the_row_note pole_moved probe_before_corpus cwd_invariance coverage_partial ghost_record pole_absent no_record orphan_block stale_second_block record_pole_skipped jobs_canonical width_exact" ;;
    downward-note-becomes-fail) printf '%s' "cwd_invariance" ;;
    partial-dispatch-compared)  printf '%s' "cwd_invariance" ;;
    # DIVIDING WITHOUT THE OBSERVED POLE puts the pole on one side of the ratio only, so the
    # ghost arm's printed denominator loses the pole's 1000s and no longer reads 113224. That is
    # a TRUE finding about the same defect; coverage_partial owns it because it is the arm whose
    # figure moves while every verdict in it stays the same.
    divisor-is-observed-pole)   printf '%s' "ghost_record" ;;
    # A FIRST-ROW SELECTOR IS ALSO AN INEXACT ONE: `--jobs 1` against rows at 12 and 16 selects
    # row 12 under it, exactly as a regex selector does. Both findings are true; jobs_mismatch
    # owns the first-row reader (it is the only arm whose SECOND block must be the one compared)
    # and width_exact stands down for it, owning the regex mutant alone.
    width-selects-first-row)    printf '%s' "width_exact" ;;
    *) printf '' ;;
  esac
}

mut() { # <label> <anchor-fixed-string> <sed-expr> <arm-that-must-fail> [count] [injected-marker]
  local label="$1" anchor="$2" expr="$3" want="$4" n_want="${5:-1}" marker="${6:-}"
  local dir="$MUTROOT/$label" copy out rc others n_anchor n_after allowed unexpected o n_mark
  # THE ANCHOR IS COUNTED BEFORE THE MUTATION, AND AGAIN AFTER. A `sed` keyed on a line that
  # no longer exists produces an unmutated copy, and `cmp -s` catches that — but a mutation
  # can also APPLY and be INSUFFICIENT, removing some of the property and leaving the rest,
  # which `cmp -s` cannot see. Measured on this very battery: deleting ONE of the probe's
  # seeds left four others that caught the same breakage, so the mutant survived while looking
  # like a coverage gap. Both counts are therefore asserted — the expected number of sites
  # BEFORE, and zero AFTER.
  n_anchor="$(grep -cF -- "$anchor" "$V")" || n_anchor=0
  MUT_COUNT=$((MUT_COUNT + 1))
  MUT_TABLE="$MUT_TABLE$label -> $want (anchor matched $n_anchor line(s), expected $n_want)
"
  # `+N` MEANS AT LEAST N, and it is how a SET-shaped anchor is declared. A mutation whose
  # subject is "every site of a predicate" cannot assert an exact count without going stale
  # the release somebody adds a site — and going stale in the direction that reads as a
  # regression in the change under test. What must hold for such an anchor is that the set is
  # PLURAL (a one-member set is a single site by another name) and that the mutation empties
  # it, which the post-mutation zero below asserts.
  case "$n_want" in
    '+'*)
      if [ "$n_anchor" -lt "${n_want#+}" ]; then
        bad "MUTANT $label: its anchor matched $n_anchor line(s), fewer than the ${n_want#+} a set-shaped mutation needs — the predicate this keys on has lost members and the mutation no longer removes a set. FIXTURE BROKEN rather than a kill."
        return
      fi ;;
    *)
      if [ "$n_anchor" -ne "$n_want" ]; then
        bad "MUTANT $label: its anchor matched $n_anchor line(s) of the subject, not the $n_want expected — a lost anchor is a lost subject and an unexpected extra site moves cells the arm did not earn. FIXTURE BROKEN rather than a kill."
        return
      fi ;;
  esac
  mkdir -p "$dir"
  cp "$SUBJ_DIR"/* "$dir/" 2>/dev/null
  copy="$dir/$SUBJ_BASE"
  [ -f "$copy" ] || { bad "MUTANT $label: the directory copy did not carry the subject"; return; }
  if ! sed -e "$expr" "$V" > "$copy.new" 2>/dev/null; then
    bad "MUTANT $label DID NOT APPLY: the sed died, so no mutant ever existed and its arms would have been scored against an untouched subject"
    return
  fi
  mv "$copy.new" "$copy"
  if cmp -s "$V" "$copy"; then
    bad "MUTANT $label: the sed matched NOTHING, so the subject was never mutated and this kill would have been fictional"
    return
  fi
  # THE POST-MUTATION CHECK DEPENDS ON THE MUTATION'S SHAPE, and conflating the two shapes is
  # itself a defect this battery hit: the zero-after rule below is correct for a mutation that
  # REMOVES or REPLACES its sites and wrong for one that INJECTS a line after an anchor, where
  # the anchor survives by construction. A removal is checked by its anchor going to zero; an
  # injection is checked by a MARKER that appears nowhere in the original and must appear in
  # the copy. Both are presence-shaped assertions about the mutation having really happened.
  if [ -n "$marker" ]; then
    n_mark="$(grep -cF -- "$marker" "$V")" || n_mark=0
    if [ "$n_mark" -ne 0 ]; then
      bad "MUTANT $label: its injection marker already appears $n_mark time(s) in the UNMUTATED subject, so its presence in the copy proves nothing"
      return
    fi
    n_mark="$(grep -cF -- "$marker" "$copy")" || n_mark=0
    if [ "$n_mark" -lt 1 ]; then
      bad "MUTANT $label: the injected line is absent from the copy, so the mutation did not take effect where it was aimed"
      return
    fi
  else
    n_after="$(grep -cF -- "$anchor" "$copy")" || n_after=0
    if [ "$n_after" -ne 0 ]; then
      bad "MUTANT $label: $n_after of its $n_anchor anchor site(s) survived the mutation, so the property was only partly removed and a SURVIVED verdict here would read as a coverage gap rather than as an insufficient mutation"
      return
    fi
  fi
  chmod +x "$copy"
  out="$(run_arms "$copy")"
  rc="$(printf '%s\n' "$out" | sed -n "s/^${want}://p")"
  if [ "$rc" = "1" ]; then
    kills=$((kills + 1))
    others="$(printf '%s\n' "$out" | grep ':1$' | grep -v "^${want}:" | cut -d: -f1 | tr '\n' ' ')"
    allowed=" $(co_kills_ok "$label") "
    unexpected=""
    for o in $others; do
      case "$allowed" in *" $o "*) : ;; *) unexpected="$unexpected $o" ;; esac
    done
    if [ -n "${unexpected// /}" ]; then
      bad "MUTANT $label killed by $want AND by:$unexpected — those arms are entangled and at least one is not independently load-bearing"
    elif [ -n "${others// /}" ]; then
      ok "MUTANT $label killed by $want, beside only its declared co-kills ($others)"
    else
      ok "MUTANT $label killed by $want, and by that arm alone"
    fi
  else
    bad "MUTANT $label SURVIVED: $want still passes against a subject that no longer does the thing that arm asserts"
  fi
}

# M1: EXIT 0 IMMEDIATELY AFTER THE PROBE. The whole corpus verdict deleted, leaving a program
# that runs its self-probe and reports nothing — which is what every wrong implementation of
# this guard has looked like. Anchored on the probe's own report line, which is the last
# statement before the corpus is opened.
mut probe-then-exit-0 \
  'seeds in both directions' \
  "/seeds in both directions/a\\
exit 0 # MUTANT-EARLY-EXIT" \
  grown \
  1 \
  'MUTANT-EARLY-EXIT'

# M2: THE COMPARATOR SEED SET DELETED — every `probe_expect` line at once.
#
# TWO MUTATIONS WERE BUILT AND MEASURED BEFORE THIS ONE WAS WRITTEN, AND BOTH ARE REPORTED
# HERE RATHER THAN SCORED, because what they measure is not what they look like.
#
# FIRST, breaking the comparator directly (`-gt` -> `-ge`, or the `+ 99` dropped) produces no
# wrong verdict at all: the subject's own self-probe catches it and exits 2 on EVERY input, so
# the mutation moves every arm and no arm owns it. That is the guard working, not entanglement,
# and the property is asserted where it can be — `arm_probe_catches_broken_comparator` builds
# both copies and demands the refusal.
#
# SECOND, deleting ONE probe seed is correctly invisible. Measured across five seeds against
# both breakages, ten pairs: every one still refused, named by a DIFFERENT surviving seed —
# delete `at-ceiling` and `ceil-not-floor-pass` catches it; delete that and `ceil-not-round` or
# `at-ceiling` does. The seeds overlap deliberately, so a site-listed mutation is INSUFFICIENT
# in exactly the way `fixture-mutants.md` names: it applies, `cmp -s` is satisfied, and the
# property survives. The repair is to key the mutation on the SUBJECT'S OWN PREDICATE and
# assert the post-mutation count is zero against a non-zero unmutated count, which `mut` does
# for every mutation through its anchor count — here the anchor is the predicate itself.
mut probe-seed-set-deleted \
  'probe_expect ' \
  '/^probe_expect /d' \
  probe_catches_broken_comparator \
  '+2'

# M4: THE ENV OVERRIDE IGNORED. The filed receipt SETS AI_DLC_POLE_BASELINE, so this mutation
# makes the program read the real baseline while the receipt still passes — a receipt-green
# non-fix. Only the decoy arm can see it.
#
# THE ANCHOR IS THE ENV TOKEN, NOT THE WHOLE ASSIGNMENT. The first cut quoted the subject's
# default path verbatim, and the excluded top-level name inside a sed program is a string I55 arm 3 reads
# as this fixture reaching a content-key-EXCLUDED path. The mutation deletes exactly the
# `${AI_DLC_POLE_BASELINE:-...}` wrapper and nothing else, so the anchor is that wrapper.
mut env-baseline-ignored \
  '${AI_DLC_POLE_BASELINE:-' \
  's|\${AI_DLC_POLE_BASELINE:-\([^}]*\)}|\1|' \
  env_override

# M5: THE SELF-PROBE SHORT-CIRCUITED. `probe_expect` returns without comparing anything, so
# every seed "passes" and the program reaches the corpus having established nothing.
#
# MEASURED: this mutant alone changes NO verdict — every seed the probe checks is one the
# correct comparator answers correctly anyway, so a short-circuited probe over a working
# comparator is silent by construction. It is observable only in combination with a broken
# comparator, which is exactly what `arm_probe_catches_broken_comparator` builds: under this
# mutant its two copies are doubly broken, reach the corpus, and return a verdict where the
# arm asserted a refusal. That is the whole reason the probe exists, and no arm reading the
# unmutated subject's output can see it.
#
# ANCHORED ON THE COMPARISON INSIDE probe_expect, not on the report line: a probe that prints
# nothing while still comparing is a different defect from one that compares nothing.
mut self-probe-short-circuited \
  '[ "$got" = "$want" ] || probe_fail' \
  's/\[ "\$got" = "\$want" \] || probe_fail/return 0; probe_fail/' \
  probe_catches_broken_comparator

# M6: THE LOWER-THE-ROW NOTE TURNED INTO A FAIL. The downward direction made blocking, which
# fires on a quiet box and blocks the push that IMPROVES the suite. It reads as a tightening
# and it is the one change the header forbids by name.
mut downward-note-becomes-fail \
  'lower the row' \
  '/lower the row/a\
  exit 1 # MUTANT-DOWNWARD-FAIL' \
  lower_the_row_note \
  1 \
  'MUTANT-DOWNWARD-FAIL'

# M7: THE COVERAGE SKIP REMOVED, so a near-solo run is COMPARED against a loaded baseline.
# This is the false red the guard would produce on most pushes, and the mutation is the
# "simplification" a reader reaches for on seeing a skip that fires often.
mut partial-dispatch-compared \
  'if [ "$((NUM * 100))" -lt "$((DEN * COV_MIN))" ]; then' \
  's/if \[ "\$((NUM \* 100))" -lt "\$((DEN \* COV_MIN))" \]; then/if false; then/' \
  partial_dispatch

# M8: THE THRESHOLD SET TO ZERO. The predicate still computes and prints a coverage figure, so
# every arm reading the figure stays green; only a near-solo run being compared shows it.
mut coverage-threshold-zero \
  'COV_MIN=90' \
  's/^COV_MIN=90$/COV_MIN=0/' \
  partial_dispatch

# M9: THE ROW-COUNT EQUALITY RESTORED -- the defect this predicate replaced. Injected after the
# coverage line, so a 220-of-227 dispatch is skipped again although its coverage is 99.87%.
mut row-count-equality-restored \
  '"$COV_TXT" "$NUM" "$DEN" "$fx_count" "$COV_MIN"' \
  '/"\$COV_TXT" "\$NUM" "\$DEN" "\$fx_count" "\$COV_MIN"$/a\
[ "$(awk '"'"'NF == 2 { n++ } END { print n + 0 }'"'"' "$DUR")" -eq "$fx_count" ] || { printf "   SKIP -- partial dispatch\\n"; exit 0; } # MUTANT-ROW-EQUALITY' \
  coverage_partial \
  1 \
  'MUTANT-ROW-EQUALITY'

# M10: THE ON-DISK JOIN DROPPED, so a ghost key the hook's merge never prunes counts as work
# this run failed to do and a full dispatch reads as 12% covered.
mut on-disk-join-dropped \
  '&& ($1 in d) { s += $2 }' \
  's/ && (\$1 in d) { s += \$2 }/ { s += $2 }/' \
  ghost_record

# M11: THE DIVISOR LEAVES OUT THE OBSERVED POLE -- the pole on ONE side of the ratio only. The
# label names the defect class the contract asked for ("a term depending on the observed pole
# asymmetrically"); the literal `DEN = OBS_SECS` reads every run >100% and dies in every arm.
# On the 220-of-227 seed (others 12294, missing units W=16, pole 830) that prints 106.6% where
# the right figure is 99.87%, and every verdict in the arm is unchanged.
mut divisor-is-observed-pole \
  'COV_BP=$((NUM * 10000 / DEN))' \
  's|^COV_BP=\$((NUM \* 10000 / DEN))$|DEN=$((DEN - OBS_SECS)); COV_BP=$((NUM * 10000 / DEN)) # MUTANT-DIVISOR|' \
  coverage_partial \
  1 \
  'MUTANT-DIVISOR'

# M12: THE BASELINE POLE ABSENT ACQUITS GROWTH. The absent-pole SKIP moved above the ceiling
# comparison, so a unit that is not the watched one growing past the ceiling is skipped.
mut absent-pole-skips-growth \
  'CEIL="$(pole_ceiling "$BL_SECS" "$BL_BAND")"' \
  '/^CEIL="\$(pole_ceiling "\$BL_SECS" "\$BL_BAND")"$/a\
[ -z "$BL_PRESENT" ] \&\& { printf "   SKIP -- baseline pole not dispatched\\n"; exit 0; } # MUTANT-ABSENT-SKIP' \
  pole_absent \
  1 \
  'MUTANT-ABSENT-SKIP'

# M14: THE MISSING-RECORD SKIP DELETED. The program still exits 0 on an absent record, via the
# zero-denominator SKIP below it -- so only an arm demanding the record be NAMED can see it.
mut no-record-skip-deleted \
  'if [ ! -s "$REC" ]; then' \
  's/if \[ ! -s "\$REC" \]; then/if false; then/' \
  no_record

# M15: THE REPEATED-DIRECTIVE REFUSAL DROPPED, so a later directive silently overwrites an
# earlier one and an orphaned block's terms bind to the next row.
mut repeat-directive-accepted \
  'if [ -n "$prev" ]; then' \
  's/if \[ -n "\$prev" \]; then/if false; then/' \
  orphan_block

# M16: THE STALE-POLE CHECK LOOKS AT THE FIRST ROW ONLY -- the single-row reader it replaced.
mut stale-check-first-row-only \
  'STALE_SCAN="$BL_ALL"' \
  's/^STALE_SCAN="\$BL_ALL"$/STALE_SCAN="${BL_ALL%%$'"'"'\\n'"'"'*}"/' \
  stale_second_block

# M17: THE OBSERVED POLE READ FROM THE MERGED RECORD instead of this run's file.
mut observed-pole-from-record \
  'OBS="$(max_row "$DUR")"' \
  's/^OBS="\$(max_row "\$DUR")"$/OBS="$(max_row "$REC")"/' \
  record_pole_skipped

# M18: THE PARSER'S WIDTH CANONICALISATION REMOVED, so `012` and `12` are two widths.
mut jobs-canonicalisation-noop \
  'jobs="$((10#$jobs))"' \
  's/^\( *\)jobs="\$((10#\$jobs))"$/\1: # MUTANT-NO-CANON/' \
  jobs_canonical \
  1 \
  'MUTANT-NO-CANON'

# M19: WIDTH SELECTION BY REGEX, so `--jobs 1` matches the row at 12.
mut width-selects-by-regex \
  "awk -v j=\"\$2\" '\$4 == j'" \
  "s/awk -v j=\"\\\$2\" '\\\$4 == j'/awk -v j=\"\$2\" '\$4 ~ j'/" \
  width_exact

# M13: THE WIDTH SELECTOR TAKES THE FIRST ROW whatever the width -- every pre-width reader.
mut width-selects-first-row \
  "awk -v j=\"\$2\" '\$4 == j'" \
  "s/awk -v j=\"\\\$2\" '\\\$4 == j'/awk -v j=\"\$2\" 'NR == 1'/" \
  jobs_mismatch

# UNMUTATED CONTROL, WITH A POSITIVE CONJUNCT. A control asserting only "nothing went wrong"
# passes against a subject replaced by `exit 0`, because rc=0 with nothing reported is exactly
# what a clean copy looks like. This one demands a NAMED arm be affirmatively green, and it is
# built the way the mutants are — a whole-directory copy — so a partial tree that made every
# mutant survive fails HERE rather than agreeing with them.
mkdir -p "$MUTROOT/control"
cp "$SUBJ_DIR"/* "$MUTROOT/control/" 2>/dev/null
chmod +x "$MUTROOT/control/$SUBJ_BASE"
CTL="$(run_arms "$MUTROOT/control/$SUBJ_BASE")"
CTL_FAILS="$(printf '%s\n' "$CTL" | grep -c ':1$')" || CTL_FAILS=0
CTL_FIRST="$(printf '%s\n' "$CTL" | sed -n 's/^grown://p')"
if [ "$CTL_FAILS" -eq 0 ] && [ "$CTL_FIRST" = "0" ]; then
  ok "CONTROL: an unmutated whole-directory copy passes every arm, and 'grown' is affirmatively green"
else
  bad "CONTROL: an unmutated copy failed $CTL_FAILS arm(s) (grown=$CTL_FIRST) — the harness is what is broken, not the subject, and every kill above is suspect"
fi

# ASSERT THE KILL COUNT IS NON-ZERO. A battery whose mutations all landed in a copy the run
# never loaded reports the same silence as one whose arms cannot fire.
[ "$kills" -eq 0 ] && bad "NO MUTANT WAS KILLED. Either the mutations landed in a copy nothing executes, or none of these arms is load-bearing."

printf '  mutant table (label -> arm that must kill it, anchor match count):\n'
printf '%s' "$MUT_TABLE" | sed 's/^/    /'

# ---------------------------------------------------------------------------------------
# THE HOOK STEP, WHEN A LIVE READ-SET TRACE OVERLAPPED THE SUITE. A green push starts a detached
# trace of its unmapped fixtures; one still running when the NEXT push's suite starts loads the
# machine under every unit, and the pole read off that run is the trace's cost as much as the
# fixture's. fixture_suite_step records the overlap BEFORE the pool starts (its own trace takes
# the same lock after), and pole_guard_step then SKIPs the comparison in one line while still
# parsing the baseline. Both halves are extracted from the hook and driven in a mktemp world
# with a stub validator that records its argv.
# ---------------------------------------------------------------------------------------
HOOK_ARMS=0
PG_HOOK="$ROOT/.githooks/pre-push"
[ -f "$PG_HOOK" ] || broken "cannot locate .githooks/pre-push at $PG_HOOK"
PGW="$WORK/pgstep"; mkdir -p "$PGW/scripts" || broken "could not create the hook-step world"
PG_LIB="$PGW/lib.sh"
echo "  hook: ${PG_HOOK#"$ROOT"/}"
# readset_pid_start is extracted beside readset_lock_stale because the reader calls it: left out,
# the call is "command not found" inside `$( )`, the reader announces a ps failure and says HELD,
# and a right-start world passes for that reason. The right-start arm below demands NO announcement.
{ awk '/^readset_pid_start\(\) \{/,/^}/' "$PG_HOOK"
  awk '/^readset_lock_stale\(\) \{/,/^}/' "$PG_HOOK"
  awk '/^pole_guard_step\(\) \{/,/^}/' "$PG_HOOK"
  printf 'overlap_probe() {\n'
  awk '/^  READSET_TRACE_OVERLAP=0$/ { p = 1 } p { print } p && /^  fi$/ { exit }' "$PG_HOOK"
  printf '}\n'
} > "$PG_LIB"
[ "$(grep -c '^[a-z_]*() {' "$PG_LIB")" -eq 4 ] && grep -q '^readset_pid_start() {' "$PG_LIB" && grep -q 'readset_lock_stale' "$PG_LIB" && grep -q 'READSET_TRACE_OVERLAP=1' "$PG_LIB" \
  || broken "could not extract readset_pid_start, readset_lock_stale, pole_guard_step and the overlap probe from $PG_HOOK"
printf '#!/bin/bash\nprintf "%%s\\n" "$*" > "$PG_ARGS"\nexit 0\n' > "$PGW/scripts/validate-suite-pole.sh"
# pg_drive <lib> <lock: live|dead|none> -> "<overlap>|<argv>|<skip line: yes|no>"
pg_drive() {
  local lib="$1" lk="$2" o="$PGW/o.$RANDOM"
  mkdir -p "$o"; rm -rf "$PGW/rl.lock"
  case "$lk" in
    live) mkdir "$PGW/rl.lock"; printf '%s %s\n' "$$" "$(date +%s)" > "$PGW/rl.lock/pid" ;;
    dead) sh -c 'exit 0' & dp=$!; wait "$dp"; mkdir "$PGW/rl.lock"; printf '%s %s\n' "$dp" "$(date +%s)" > "$PGW/rl.lock/pid" ;;
  esac
  ( cd "$PGW" || exit 1
    . "$lib"
    READSET_LOCAL="$PGW/rl"; FIXTURE_JOBS=12; LASTRUN_RECORD=last.tsv; DURATIONS_RECORD=dur.tsv; SUITE_SKIPPED=0
    export PG_ARGS="$o/args"
    overlap_probe > "$o/probe" 2>&1
    pole_guard_step > "$o/step" 2>&1
    printf '%s' "$READSET_TRACE_OVERLAP" > "$o/ov"
  )
  printf '%s|%s|%s' "$(cat "$o/ov" 2>/dev/null)" "$(cat "$o/args" 2>/dev/null)" \
    "$(grep -q 'SKIP: a read-set live trace overlapped this run' "$o/step" && echo yes || echo no)"
}
PG_COMPARE="0|--durations last.tsv --record dur.tsv --jobs 12|no"
PG_SKIP="1|--durations /dev/null --jobs 12|yes"
pg_arm() { HOOK_ARMS=$((HOOK_ARMS + 1)); if [ "$2" = "$3" ]; then ok "$4"; else bad "$4 -- got '$2', want '$3'"; fi; }
pg_arm live "$(pg_drive "$PG_LIB" live)" "$PG_SKIP" \
  "hook step: a LIVE trace lock at suite start records the overlap, and the pole step SKIPs in one line and parses the baseline only"
pg_arm none "$(pg_drive "$PG_LIB" none)" "$PG_COMPARE" \
  "hook step: with no trace lock the pole step compares this run's record, and prints no overlap line"
pg_arm dead "$(pg_drive "$PG_LIB" dead)" "$PG_COMPARE" \
  "hook step: a lock whose pid is DEAD is stale, not an overlap -- the pole is compared"
# Mutants of the extracted lib, each count-checked, each scored on the arm it must break.
pg_mut() { # <name> <from> <to> <lock> <arm's correct result>
  local m="$PGW/m.$1.sh" n r
  n="$(grep -cF -- "$2" "$PG_LIB")" || n=0
  HOOK_ARMS=$((HOOK_ARMS + 1))
  if [ "$n" != 1 ]; then bad "hook-step MUTANT $1: anchor matched $n time(s), not 1 -- DID NOT APPLY"; return; fi
  MF="$2" MT="$3" awk '{ i = index($0, ENVIRON["MF"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["MT"] substr($0, i + length(ENVIRON["MF"])); print }' "$PG_LIB" > "$m"
  if cmp -s "$PG_LIB" "$m"; then bad "hook-step MUTANT $1: the copy is unchanged"; return; fi
  r="$(pg_drive "$m" "$4")"
  if [ "$r" = "$5" ]; then bad "hook-step MUTANT $1 SURVIVED: '$r'"; else ok "hook-step MUTANT $1 is KILLED: '$r'"; fi
}
pg_mut noskip 'if [ "${READSET_TRACE_OVERLAP:-0}" = 1 ]; then' 'if false; then' live "$PG_SKIP"
pg_mut nodetect '    READSET_TRACE_OVERLAP=1' '    :' live "$PG_SKIP"
pg_mut nostale '[ -d "$READSET_LOCAL.lock" ] && ! readset_lock_stale "$READSET_LOCAL.lock"' '[ -d "$READSET_LOCAL.lock" ]' dead "$PG_COMPARE"

# THE LOCK'S START TIME (BL-463). `kill -0` alone reads a REUSED pid as a live trace, so the lock
# records the start time of its pid on line 2 and the reader compares it. Six worlds, judged by
# calling readset_lock_stale directly and reading its exact return code (0 stale, 1 held, anything
# else is an error and never scores as either) and whether it printed the ps-fallback announcement.
#
# EVERY SEED COMES FROM THE UNMUTATED HOOK. The seed lib below is readset_pid_start plus the hook's
# own writer line, extracted, so the right-start lock is what the real writer emits, never a string
# typed here; and a mutant of the judge cannot also move its seed, which would let a normalisation
# mutant survive by symmetry.
#   wrong       the A7 seed: a LIVE pid (this fixture) with a start time it never had   -> stale
#   right       the real writer's lock for that pid, judged under LC_ALL=C TZ=UTC0       -> held, silent
#   legacylive  `pid epoch` only, as an older hook wrote it, live pid                    -> held, silent
#   legacydead  the same with a dead pid                                                 -> stale, silent
#   psfail      the real writer's lock, judged with a PATH `ps` that exits 1             -> held, announced
#   split       written under de_DE/Asia/Tokyo, judged under fr_FR/America/Los_Angeles  -> whatever `right` reads
# `split` is scored RELATIVE to `right` under the same lib, so a mutant that breaks every held-with-
# start world (no normalisation) is owned by `right` alone, and one that breaks only the cross-env
# case (no pin) is owned by `split` alone. On the unmutated hook `right` is asserted held and silent,
# so `split` is held and silent by that conjunct.
PJ_WLINE="printf '%s %s\\n%s\\n' \"\$tp\""
PJ_N="$(grep -cF -- "$PJ_WLINE" "$PG_HOOK")" || PJ_N=0
[ "$PJ_N" -eq 1 ] || broken "the lock writer line ($PJ_WLINE) occurs $PJ_N time(s) in $PG_HOOK, not 1"
PJ_SEEDLIB="$PGW/seed.sh"
{ awk '/^readset_pid_start\(\) \{/,/^}/' "$PG_HOOK"
  printf 'pj_write_lock() { local tp="$1" lk="$2"\n'
  grep -F -- "$PJ_WLINE" "$PG_HOOK"
  printf '}\n'
} > "$PJ_SEEDLIB"
PJ_LIVE="$( . "$PJ_SEEDLIB"; readset_pid_start "$$" )" || PJ_LIVE=""
[ -n "$PJ_LIVE" ] || broken "readset_pid_start printed nothing for this fixture's own live pid $$ -- no world below can reach the start comparison"
for _w in wrong right legacylive legacydead psfail split; do mkdir -p "$PGW/j.$_w.lock" || broken "could not create the $_w lock world"; done
printf '%s %s\n%s\n' "$$" "$(date +%s)" 'Thu Jan  1 00:00:00 1970' > "$PGW/j.wrong.lock/pid"
_s="$(sed -n 2p "$PGW/j.wrong.lock/pid")"; _s="$(set -f; set -- $_s; printf '%s' "$*")"
[ "$_s" != "$PJ_LIVE" ] || broken "the wrong-start seed '$_s' equals the live start '$PJ_LIVE' -- the world cannot discriminate"
( . "$PJ_SEEDLIB"; pj_write_lock "$$" "$PGW/j.right.lock" )
[ "$(sed -n 1p "$PGW/j.right.lock/pid" | cut -d' ' -f1)" = "$$" ] && [ "$(sed -n 2p "$PGW/j.right.lock/pid")" = "$PJ_LIVE" ] \
  || broken "the real writer did not record pid $$ and its start '$PJ_LIVE': $(tr '\n' '/' < "$PGW/j.right.lock/pid")"
cp "$PGW/j.right.lock/pid" "$PGW/j.psfail.lock/pid"
printf '%s %s\n' "$$" "$(date +%s)" > "$PGW/j.legacylive.lock/pid"
sh -c 'exit 0' & _dp=$!; wait "$_dp"
printf '%s %s\n' "$_dp" "$(date +%s)" > "$PGW/j.legacydead.lock/pid"
_a="$(LC_ALL=de_DE.UTF-8 TZ=Asia/Tokyo ps -o lstart= -p "$$")"; _b="$(LC_ALL=fr_FR.UTF-8 TZ=America/Los_Angeles ps -o lstart= -p "$$")"
[ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" != "$_b" ] \
  || broken "unpinned ps reads the same start under the two split environments ('$_a' / '$_b') -- the split world cannot discriminate"
( export LANG=de_DE.UTF-8 LC_ALL=de_DE.UTF-8 TZ=Asia/Tokyo; . "$PJ_SEEDLIB"; pj_write_lock "$$" "$PGW/j.split.lock" )
[ "$(sed -n 2p "$PGW/j.split.lock/pid")" = "$PJ_LIVE" ] || broken "the writer under de_DE/Tokyo did not record the pinned start '$PJ_LIVE'"
mkdir -p "$PGW/psbin" && printf '#!/bin/sh\nexit 1\n' > "$PGW/psbin/ps" && chmod +x "$PGW/psbin/ps" || broken "could not build the failing ps stub"
pj_judge() { # <lib> <world> -> "<stale|held|err<rc>>|<ann|noann>"
  local o="$PGW/jo.$2.$RANDOM" rc
  mkdir -p "$o"
  ( . "$1"
    case "$2" in
      right) export LC_ALL=C TZ=UTC0 ;;
      split) export LANG=fr_FR.UTF-8 LC_ALL=fr_FR.UTF-8 TZ=America/Los_Angeles ;;
      psfail) PATH="$PGW/psbin:$PATH"; [ "$(command -v ps)" = "$PGW/psbin/ps" ] || exit 7 ;;
    esac
    readset_lock_stale "$PGW/j.$2.lock" > "$o/out" 2>&1; echo "$?" > "$o/rc" )
  rc="$(cat "$o/rc" 2>/dev/null)"
  case "$rc" in 0) rc=stale ;; 1) rc=held ;; *) rc="err${rc:-none}" ;; esac
  printf '%s|%s' "$rc" "$(grep -q 'could not read the start time of lock pid' "$o/out" && echo ann || echo noann)"
}
PJ_WORLDS="wrong right legacylive legacydead psfail split"
pj_want() { # <world> <right's result under the same lib>
  case "$1" in
    wrong|legacydead) printf 'stale|noann' ;;
    right|legacylive) printf 'held|noann' ;;
    psfail) printf 'held|ann' ;;
    split) printf '%s' "$2" ;;
  esac
}
pj_eval() { # <lib>: sets PJ_R_<world> and PJ_FLIP, the worlds whose result is not the wanted one
  local w r rr
  rr="$(pj_judge "$1" right)"; PJ_FLIP=""
  for w in $PJ_WORLDS; do
    if [ "$w" = right ]; then r="$rr"; else r="$(pj_judge "$1" "$w")"; fi
    eval "PJ_R_$w=\$r"
    [ "$r" = "$(pj_want "$w" "$rr")" ] || PJ_FLIP="$PJ_FLIP${PJ_FLIP:+ }$w"
  done
}
pj_eval "$PG_LIB"
pj_arm() { # <world> <text>
  local r; HOOK_ARMS=$((HOOK_ARMS + 1)); eval "r=\$PJ_R_$1"
  if [ "$r" = "$(pj_want "$1" "$PJ_R_right")" ]; then ok "$2"; else bad "$2 -- got '$r', want '$(pj_want "$1" "$PJ_R_right")'"; fi
}
pj_arm wrong "lock start: a LIVE pid whose recorded start time is not its own (a reused pid) is STALE"
pj_arm right "  the real writer's lock for a live pid is HELD, with no ps-fallback announcement"
pj_arm legacylive "  a two-field lock from an older hook with a live pid is HELD, judged as before, with no announcement"
pj_arm legacydead "  a two-field lock from an older hook with a dead pid is STALE"
pj_arm psfail "  a ps that fails (PATH stub exiting 1) leaves a live lock HELD and says so in one line"
pj_arm split "  written under de_DE/Asia/Tokyo and judged under fr_FR/America/Los_Angeles, the lock reads as it does under C/UTC0"
# Each mutant is scored against ALL six worlds, and must move exactly its own.
pj_mut() { # <name> <from> <to> <the one world it must move>
  local m="$PGW/m.pj.$1.sh" n
  HOOK_ARMS=$((HOOK_ARMS + 1))
  n="$(grep -cF -- "$2" "$PG_LIB")" || n=0
  if [ "$n" != 1 ]; then bad "lock-start MUTANT $1: anchor matched $n time(s), not 1 -- DID NOT APPLY"; return; fi
  MF="$2" MT="$3" awk '{ i = index($0, ENVIRON["MF"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["MT"] substr($0, i + length(ENVIRON["MF"])); print }' "$PG_LIB" > "$m"
  if cmp -s "$PG_LIB" "$m"; then bad "lock-start MUTANT $1: the copy is unchanged"; return; fi
  pj_eval "$m"
  if [ "$PJ_FLIP" = "$4" ]; then ok "lock-start MUTANT $1 is KILLED by '$4' alone: '$(eval "printf '%s' \"\$PJ_R_$4\"")'"
  else bad "lock-start MUTANT $1 moved '${PJ_FLIP:-nothing}', want exactly '$4'"; fi
}
pj_mut nostart '    [ "$c" != "$s" ] && return 0' '    :' wrong
pj_mut nopin 'LC_ALL=C TZ=UTC0 ps -o lstart=' 'ps -o lstart=' split
pj_mut psstale "alone\\n' \"\$p\"" "alone\\n' \"\$p\"; return 0" psfail
pj_mut nonorm '  set -- $x' '  set -- "$x"' right
# No mutant here deletes the legacy branch (`[ -n "$s" ] || return 1`): one was built and moved
# `legacylive` AND the `live` hook-step arm above, whose seed is also a two-field lock. That arm
# owns the regression (an upgrade turning every older lock stale) and kills it; `legacylive` adds
# only the no-announcement conjunct.

# EXPECTED_ASSERTIONS, DERIVED FROM THE ARM LIST rather than typed. A hardcoded total goes
# stale the release somebody adds an arm, and it goes stale SILENTLY in the direction that
# matters — a fixture reporting fewer assertions than it has arms reads as a complete run.
# The three addends are counted where they are produced: ARM_COUNT from $ARMS, MUT_COUNT
# incremented by every `mut` call, and the unmutated control, which is straight-line and
# cannot vary.
EXPECTED_ASSERTIONS=$((ARM_COUNT + MUT_COUNT + 1 + HOOK_ARMS))
# HOOK_WANT is derived from this file's own call lines: one assertion per pg_arm/pg_mut/pj_arm/pj_mut.
HOOK_WANT="$(grep -cE '^(pg_arm|pg_mut|pj_arm|pj_mut) ' "$HERE/run.sh")" || HOOK_WANT=0
[ "$HOOK_WANT" -ge 16 ] || broken "counted $HOOK_WANT hook-step call lines in $HERE/run.sh, expected at least 16"
[ "$HOOK_ARMS" -eq "$HOOK_WANT" ] || { printf '  FAIL  %s hook-step assertions ran, %s expected\n' "$HOOK_ARMS" "$HOOK_WANT"; fails=$((fails + 1)); }
if [ "$asserts" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf '  FAIL  %s assertions ran, %s expected — an arm did not execute\n' "$asserts" "$EXPECTED_ASSERTIONS"
  fails=$((fails + 1))
fi

printf '  %s failed, %s mutant(s) killed, %s assertions\n' "$fails" "$kills" "$asserts"
[ "$fails" -eq 0 ] || { echo "suite-pole-guard: FAIL ($fails)"; exit 1; }
echo "suite-pole-guard: PASS"
exit 0
