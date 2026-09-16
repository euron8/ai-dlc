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

# RESOLVE THE ROOT BY WALKING UP FOR `VERSION`, never by counting `..` hops: a hop count
# answers differently from the repo root, from a subdirectory and from a sandbox copy, and
# the sandbox answer is the silent one. This fixture is `.dist-only`, so there is no second
# install layout to name — the subject exists in this tree or nowhere.
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
# A PRECONDITION FAILURE IS NEVER A SILENT PASS. Every arm below reads the subject's output,
# so a run that cannot invoke it produces nothing — and "nothing" scores green on any arm
# phrased as an absence. Refuse loudly instead.
broken() { printf '  FIXTURE BROKEN: %s\n' "$1" >&2; echo "suite-pole-guard: FIXTURE BROKEN" >&2; exit 2; }

echo "suite-pole-guard:"

[ -f "$ROOT/VERSION" ] || broken "no VERSION marker walking up from $HERE, so the repo root could not be resolved"
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
  return 0
}

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
RC=0
OUT=""
drive() { # <args...> -> output in $OUT, exit code in $RC
  OUT="$(bash "$SUBJ" "$@" 2>&1)"; RC=$?
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

# PARTIAL DISPATCH -> 0 with SKIP naming `partial`. THE FALSE RED THIS GUARD WOULD OTHERWISE
# PRODUCE ON MOST PUSHES: the read-set skip narrows the dispatch list in place, so the pole is
# timed beside thirty units rather than two hundred and the figure is near-solo.
#
# THE NEAR-MISS IS IN THE SAME ARM and it is what makes this discriminate: a full-length file
# over the same tree must be COMPARED, not skipped. Without it, an implementation that skips
# everything passes.
arm_partial_dispatch() {
  local w="$1" out rc_partial rc_full
  mktree "$w" 5 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 5 || return 1
  mkdur "$w/full.tsv" 5 fx1 100 || return 1
  # Three rows against five fixture directories.
  printf 'fx1 100\nfx2 1\nfx3 1\n' > "$w/partial.tsv" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/partial.tsv" --jobs 12; out="$OUT"; rc_partial=$RC
  grep -qF 'SKIP' <<<"$out" || return 1
  grep -qF 'partial' <<<"$out" || return 1
  grep -qF '3 of 5' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/full.tsv" --jobs 12; out="$OUT"; rc_full=$RC
  grep -qF 'pole fx1 100s' <<<"$out" || return 1
  [ "$rc_partial" -eq 0 ] && [ "$rc_full" -eq 0 ]
}

# `--jobs` DISAGREEING WITH `# jobs:` -> 0 with SKIP naming `pool width`. A different width is
# a different machine for a loaded figure. The near-miss — the matching width — is the FULL
# COMPARISON, asserted in the same arm for the same reason as above.
arm_jobs_mismatch() {
  local w="$1" out rc_mismatch rc_match
  mktree "$w" 3 || return 1
  mkbase "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"; rc_mismatch=$RC
  grep -qF 'SKIP' <<<"$out" || return 1
  grep -qF 'pool width' <<<"$out" || return 1
  # THE SAME GROWN FIGURE AT THE MATCHING WIDTH MUST FAIL. This is the conjunct that stops a
  # skip-everything implementation from passing: the only difference between the two drives
  # is the width.
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc_match=$RC
  [ "$rc_mismatch" -eq 0 ] && [ "$rc_match" -eq 1 ]
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
  grep -qF 'ONE data row' <<<"$out" || return 1
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
  [ "$rc_two" -eq 2 ] && [ "$rc_noband" -eq 2 ] && [ "$rc_nojobs" -eq 2 ] && [ "$rc_stale" -eq 2 ]
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
  # fx2 is now the longest, at a figure inside fx1's band.
  printf 'fx1 50\nfx2 105\nfx3 1\n' > "$w/dur.tsv" || return 1
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
  o_sub="$( cd "$w/core/fixtures/fx1" && bash "$SUBJ" --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12 2>&1 )"; r_sub=$?
  o_slash="$( cd / && bash "$SUBJ" --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12 2>&1 )"; r_slash=$?
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
lower_the_row_note pole_moved probe_before_corpus cwd_invariance"

ARM_COUNT=0
for _a in $ARMS; do ARM_COUNT=$((ARM_COUNT + 1)); done

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
    partial_dispatch)    msg="a partial dispatch SKIPs naming the counts, while a full-length file over the same tree is COMPARED" ;;
    jobs_mismatch)       msg="a pool width differing from the baseline's SKIPs naming 'pool width', while the same figure at the matching width fails" ;;
    refusals)            msg="two data rows, a missing band, a missing jobs, and a pole naming no fixture directory each exit 2 and name the cause" ;;
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
# SANITY ON THE REAL TREE. Everything above runs on synthesised trees, which cannot tell
# whether the TRACKED baseline is readable by the shipping grammar. These two arms are the
# join, and they are the two ways that file rots green.
# ---------------------------------------------------------------------------------------
REAL_BASE="$ROOT/docs/suite-pole-baseline.tsv"
if [ ! -f "$REAL_BASE" ]; then
  bad "the tracked baseline is absent at ${REAL_BASE#"$ROOT"/} — the pre-push step reads it by default and would refuse on every push"
else
  # A FULL DURATIONS FILE CONSTRUCTED FROM THE REAL TREE: one row per real fixture directory,
  # the baseline's own pole row carrying the baseline's own figure. Comparing that against the
  # baseline must PASS — it is the same number — which exercises the real file through the
  # whole program rather than grepping it.
  REAL_FX="$(find "$ROOT/core/fixtures" -mindepth 2 -maxdepth 2 -name run.sh -type f 2>/dev/null | wc -l | tr -d ' ')"
  case "$REAL_FX" in ''|*[!0-9]*) REAL_FX=0 ;; esac
  [ "$REAL_FX" -gt 0 ] || broken "no fixture directories found under $ROOT/core/fixtures, so the real-tree arms have no population"
  REAL_POLE="$(awk '/^[^#]/ && NF == 2 { print $1; exit }' "$REAL_BASE")"
  REAL_SECS="$(awk '/^[^#]/ && NF == 2 { print $2; exit }' "$REAL_BASE")"
  REAL_JOBS="$(sed -n 's/^#[[:blank:]]*jobs:[[:blank:]]*\([0-9][0-9]*\).*$/\1/p' "$REAL_BASE" | sed -n 1p)"
  if [ -z "$REAL_POLE" ] || [ -z "$REAL_SECS" ] || [ -z "$REAL_JOBS" ]; then
    bad "the tracked baseline yields pole='$REAL_POLE' secs='$REAL_SECS' jobs='$REAL_JOBS' — the arms below cannot be constructed from it"
  else
    RD="$WORK/real.durations"
    : > "$RD"
    # THE POLE ROW IS WRITTEN LAST AND THE OTHERS CARRY 1, so the max really is the baseline's
    # figure and no other row can reach it. `find` ORDER is not read here; only the set is.
    find "$ROOT/core/fixtures" -mindepth 2 -maxdepth 2 -name run.sh -type f 2>/dev/null \
      | sed 's#/run\.sh$##; s#.*/##' \
      | awk -v p="$REAL_POLE" -v s="$REAL_SECS" '{ if ($0 == p) { hit = 1; print $0, s } else print $0, 1 } END { if (!hit) exit 3 }' > "$RD"
    awk_rc=$?
    n_rd="$(grep -c . "$RD")" || n_rd=0
    if [ "$awk_rc" -eq 3 ]; then
      bad "the tracked baseline names pole '$REAL_POLE', which is not among this tree's $REAL_FX fixture directories — the guard refuses on it and every push would exit 2"
    elif [ "$n_rd" -ne "$REAL_FX" ]; then
      broken "constructed $n_rd durations rows against $REAL_FX fixture directories; the partial-dispatch precondition would SKIP and the sanity arm would assert nothing"
    else
      # `--root "$ROOT"` IS NOT OPTIONAL HERE, AND THE REPO-ROOT RUN CANNOT SEE THAT. Without
      # it the subject walks up from the CWD for VERSION — which succeeds from the repo root
      # and REFUSES from anywhere else. Measured: green from the repo root, `REFUSE -- no
      # VERSION found walking up from /private/tmp` when the same fixture was driven from /tmp
      # by absolute path. A fixture green only from one cwd is asserting about that cwd.
      out="$(bash "$V" --root "$ROOT" --baseline "$REAL_BASE" --durations "$RD" --jobs "$REAL_JOBS" 2>&1)"; rc=$?
      if [ "$rc" -eq 0 ] && grep -qF "pole $REAL_POLE $REAL_SECS" <<<"$out"; then
        ok "the TRACKED baseline parses under the shipping grammar and compares clean against a full $REAL_FX-row durations file carrying its own figure"
      else
        bad "the tracked baseline did not survive the shipping program (rc=$rc): $(printf '%s\n' "$out" | sed -n 1p)"
      fi
    fi
    # AND ITS POLE NAMES A DIRECTORY THAT EXISTS. Asserted directly as well as through the run
    # above, because the run's refusal and a dozen other refusals share one exit code.
    if [ -d "$ROOT/core/fixtures/$REAL_POLE" ]; then
      ok "the tracked baseline's pole '$REAL_POLE' names an existing directory under core/fixtures/"
    else
      bad "the tracked baseline's pole '$REAL_POLE' is not a directory under core/fixtures/ — the guard exits 2 on every push until the row is re-pointed"
    fi
  fi
fi

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
    probe-then-exit-0)          printf '%s' "equal within_band ceiling_boundary ceil_arithmetic env_override baseline_flag no_measurement partial_dispatch jobs_mismatch refusals lower_the_row_note pole_moved probe_before_corpus cwd_invariance" ;;
    downward-note-becomes-fail) printf '%s' "cwd_invariance" ;;
    partial-dispatch-compared)  printf '%s' "cwd_invariance" ;;
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
mut env-baseline-ignored \
  'BASE="${OPT_BASE:-${AI_DLC_POLE_BASELINE:-$ROOT/docs/suite-pole-baseline.tsv}}"' \
  's|BASE="\${OPT_BASE:-\${AI_DLC_POLE_BASELINE:-\$ROOT/docs/suite-pole-baseline.tsv}}"|BASE="${OPT_BASE:-$ROOT/docs/suite-pole-baseline.tsv}"|' \
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

# M7: THE PARTIAL-DISPATCH SKIP REMOVED, so a narrowed run is COMPARED against a full-suite
# baseline. This is the false red the guard would produce on most pushes, and the mutation is
# the "simplification" a reader reaches for on seeing a skip that fires often.
mut partial-dispatch-compared \
  'if [ "$dur_rows" -ne "$fx_count" ]; then' \
  's/if \[ "\$dur_rows" -ne "\$fx_count" \]; then/if false; then/' \
  partial_dispatch

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

# EXPECTED_ASSERTIONS, DERIVED FROM THE ARM LIST rather than typed. A hardcoded total goes
# stale the release somebody adds an arm, and it goes stale SILENTLY in the direction that
# matters — a fixture reporting fewer assertions than it has arms reads as a complete run.
# The three addends are counted where they are produced: ARM_COUNT from $ARMS, MUT_COUNT
# incremented by every `mut` call, and the two real-tree arms plus the control, which are
# straight-line and cannot vary.
EXPECTED_ASSERTIONS=$((ARM_COUNT + MUT_COUNT + 3))
if [ "$asserts" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf '  FAIL  %s assertions ran, %s expected — an arm did not execute\n' "$asserts" "$EXPECTED_ASSERTIONS"
  fails=$((fails + 1))
fi

printf '  %s failed, %s mutant(s) killed, %s assertions\n' "$fails" "$kills" "$asserts"
[ "$fails" -eq 0 ] || { echo "suite-pole-guard: FAIL ($fails)"; exit 1; }
echo "suite-pole-guard: PASS"
exit 0
