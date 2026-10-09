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

# AN ENFORCED BASELINE. Since BL-465 a tracked row is only a calibrating SEED and never FAILs, so
# every comparator arm reads its baseline from HISTORY: mkbase writes the tracked row AND, beside
# it as `<file>.hist`, three history rows at the row's width, pole, figure and fixture count, under
# a `# history-band:` equal to the row's band. `drive` passes that file as --history whenever the
# baseline it resolves has one. The comparison and GROWN lines then read exactly as they did
# against the tracked row -- same pole, figure, band and ceiling; only the source differs.
#
# THE TRACKED BLOCK SITS AT WIDTH 16, WHICH NO mkbase ARM DRIVES. Those arms then read history ALONE
# at the width they drive, so a subject that prefers a seed over history cannot move them -- that
# mutant is history_precedence's to own, and only an arm with a seed AT the driven width can see it.
# The block still names the same pole, so the stale-pole scan over every block reads it as before.
#
# THE ROWS ARE SEVEN-COLUMN, dispatched count = the tree's fixture count, and their load is the load
# the arm's own runs carry -- 2 on a 3-fixture tree (two units at 1s beside the pole, as mkdur writes),
# 12294 on the 227 template (the 219 other units big_rows writes) -- so a subject keyed on load reads
# these rows as comparable exactly as one keyed on count does, and the load-key mutant stays with the
# arm built to separate the two (uniform_slowdown).
mkbase() { # <file> <pole-name> <secs> <band> <jobs> <fixtures>
  local i ld=2
  [ "$6" -eq 227 ] && ld=12294
  printf '# a prose comment the parser ignores\n# history-band: %s\n# band: %s\n# jobs: 16\n# fixtures: %s\n%s %s\n' \
    "$4" "$4" "$6" "$2" "$3" > "$1" || return 1
  : > "$1.hist" || return 1
  for i in 1 2 3; do printf '%s\t%s\t%s\t%s\t1790000000\t%s\t%s\n' "$5" "$2" "$3" "$6" "$ld" "$6" >> "$1.hist" || return 1; done
}
# A SEED-ONLY BASELINE: the tracked row and `# history-band: 33`, no history. What the history arms
# and the seed arms start from.
mkseed() { # <file> <pole-name> <secs> <band> <jobs> <fixtures>
  printf '# a prose comment the parser ignores\n# history-band: 33\n# band: %s\n# jobs: %s\n# fixtures: %s\n%s %s\n' \
    "$4" "$5" "$6" "$2" "$3" > "$1"
}

# A durations file PLUS the width sidecar the hook writes beside it after a green pool. Without
# the sidecar the subject never records, which is what every pre-BL-465 arm above relies on: they
# use plain `mkdur` and so cannot write a history row whatever the subject does.
mkdurj() { # <file> <n-fixtures> <pole-name> <pole-seconds> <jobs>
  mkdur "$1" "$2" "$3" "$4" || return 1
  printf '%s\n' "$5" > "$1.jobs" || return 1
}

# HISTORY ROWS IN THE PRODUCER'S FORMAT: `<jobs>\t<pole>\t<secs>\t<fixtures>\t<epoch>\t<load>\t
# <dispatched>`, which arm history_first_record asserts the subject itself writes. Seeded directly
# where an arm needs rows the subject would never have admitted in that order (another width's rows,
# an older outlier); arms about what the subject WRITES drive it instead (producer_sequential, the
# laundering arms, load_excludes_pole). `hrow` is a row from a 3-unit dispatch, the shape of every
# 3-fixture world; `hrow7` names the dispatched count; `hrow5` is a LEGACY row, written before the
# load and count columns existed and never usable.
hrow() { # <file> <jobs> <pole> <secs>  -- load 2, what mkdur/mkdurj runs on a 3-fixture tree carry
  printf '%s\t%s\t%s\t3\t%s\t2\t3\n' "$2" "$3" "$4" "1790000000" >> "$1"
}
hrow7() { # <file> <jobs> <pole> <secs> <dispatched> [load]
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$2" "$3" "$4" "$5" "1790000000" "${6:-0}" "$5" >> "$1"
}
hrow5() { # <file> <jobs> <pole> <secs>
  printf '%s\t%s\t%s\t3\t%s\n' "$2" "$3" "$4" "1790000000" >> "$1"
}
# A PRODUCER RUN on a tree: `<fxN:secs ...>` becomes the durations file, the record is the same rows,
# and the sidecar names the width -- what a green pool at that width publishes. Output in $OUT/$RC.
prun() { # <tree> <jobs> <fxN:secs ...>
  local t="$1" j="$2" p; shift 2
  : > "$t/last"
  for p in "$@"; do printf '%s %s\n' "${p%%:*}" "${p#*:}" >> "$t/last"; done
  cp "$t/last" "$t/last.rec" || return 1
  printf '%s\n' "$j" > "$t/last.jobs" || return 1
  drive --root "$t" --baseline "$t/base.tsv" --durations "$t/last" --jobs "$j"
}
# Ten units fx<from>..fx<from+n-1> at <secs> each, as prun arguments.
units() { # <from> <n> <secs>
  local i="$1" e=$(($1 + $2)) a=""
  while [ "$i" -lt "$e" ]; do a="$a fx$i:$3"; i=$((i + 1)); done
  printf '%s' "$a"
}
# Since option (a) a recorded run appends one row PER DISPATCHED UNIT, so "one row per run" is a count
# of one unit's rows: `hlines <file> <unit>`. Without a unit it is the file's whole line count, which is
# what an arm asserting that NOTHING was appended (by any unit) wants.
hlines() { # <file> [unit] -> line count (of that unit's rows), 0 when absent
  if [ ! -f "$1" ]; then echo 0; return; fi
  if [ -n "${2:-}" ]; then awk -F'\t' -v u="$2" '$2 == u { n++ } END { print n + 0 }' "$1"
  else awk 'END { print NR }' "$1"; fi
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
#
# EVERY DRIVE NAMES A HISTORY FILE (BL-465). run_arms sets DRIVE_HIST to `<arm dir>/hist` before
# each arm, and drive appends `--history "$DRIVE_HIST"` unless the arm passed its own. Without it
# the subject's default would resolve the git common dir of whatever repository the fixture's
# TMPDIR sits in -- or, from a probe root that is not a repository, record nothing at all.
RC=0
OUT=""
DRIVE_HIST=""
drive() { # <args...> -> output in $OUT, exit code in $RC
  local a prev="" dur="" has_rec=0 has_hist=0 base="" root="" h
  for a in "$@"; do
    [ "$prev" = "--durations" ] && dur="$a"
    [ "$prev" = "--baseline" ] && base="$a"
    [ "$prev" = "--root" ] && root="$a"
    [ "$a" = "--record" ] && has_rec=1
    [ "$a" = "--history" ] && has_hist=1
    prev="$a"
  done
  # The baseline the SUBJECT will read, resolved the way it resolves it, so an mkbase world gets the
  # history written beside that baseline: --baseline, else the env override, else the root default.
  [ -n "$base" ] || base="${AI_DLC_POLE_BASELINE:-$root/docs/suite-pole-baseline.tsv}"
  h="$DRIVE_HIST"; [ -f "$base.hist" ] && h="$base.hist"
  [ "$has_hist" -eq 0 ] && [ -n "$h" ] && set -- "$@" --history "$h"
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
  out="$(bash "$ge" --root "$w" --baseline "$w/base.tsv" --durations "$w/at.tsv" --jobs 12 --history "$w/hist" 2>&1)"; rc_ge=$?
  grep -qF 'SELF-PROBE MISS' <<<"$out" || return 1
  out="$(bash "$floor" --root "$w" --baseline "$w/base.tsv" --durations "$w/at.tsv" --jobs 12 --history "$w/hist" 2>&1)"; rc_floor=$?
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
  # SEED BASELINES, NO HISTORY: the file read is then the only thing that decides the figure
  # compared, and the figure is printed. (Given history, a mutant reading the decoy would still
  # be handed the right history and the arm could not see it.) Both seeds keep 1000 inside the
  # band, so neither run reaches the seed-above-ceiling path, which tracked_seed owns.
  # The DECOY at the default location: 1000, compared as `baseline fx1 1000s`.
  mkseed "$w/docs/suite-pole-baseline.tsv" fx1 1000 15 12 3 || return 1
  # The env baseline: 900, compared as `baseline fx1 900s` (ceiling 1035).
  mkseed "$w/env.tsv" fx1 900 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  # CONTROL, IN THE SAME ARM: with no env set the decoy is read. That is what proves the decoy
  # really would have given a different answer, rather than the arm asserting a figure the tree
  # produces for some other reason.
  drive --root "$w" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'against baseline fx1 1000s' <<<"$out" || return 1
  AI_DLC_POLE_BASELINE="$w/env.tsv" drive --root "$w" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'against baseline fx1 900s' <<<"$out" || return 1
}

# `--baseline` likewise, against the same decoy. The flag and the env are two delivery paths
# to one value and a program can honour either alone.
arm_baseline_flag() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/docs/suite-pole-baseline.tsv" fx1 1000 15 12 3 || return 1
  mkseed "$w/flag.tsv" fx1 900 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  drive --root "$w" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'against baseline fx1 1000s' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/flag.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'against baseline fx1 900s' <<<"$out" || return 1
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

# (C) A LEGACY (5-column) HISTORY ROW IS NEVER USABLE AND NEVER COUNTS TOWARD ADMISSION. Those rows
# carry no dispatched count, so nothing says what they are comparable to. Width 4 on a 3-fixture tree,
# a FULL-share run (every unit dispatched, 100% of the record), so the retired share test would have
# admitted them:
#   three HUGE legacy rows (fx1 5000): a 1000s pole is not compared against them -- it CALIBRATES,
#     names `3 legacy`, and records. Read as usable, B = 5000 and the run prints a comparison.
#     Nor is it announced as the width's FIRST pole (D): the width holds rows, just no usable one.
#   three SMALL legacy rows (fx1 100): the same 1000s pole is still recorded -- legacy rows do not
#     count toward the K rows that make a calibrating run's admission apply.
#
# THE SEED IS AT THE DRIVEN WIDTH (fx1 1000, so both runs sit inside it): with no usable row the run is
# a seed run, which records under admission exactly as a calibrating one does, and how a width with no
# row is handled -- or which tracked row is selected -- is not this arm's to see.
arm_legacy_never_usable() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 1000 15 4 3 || return 1
  hrow5 "$w/hbig" 4 fx1 5000; hrow5 "$w/hbig" 4 fx1 5000; hrow5 "$w/hbig" 4 fx1 5000
  mkdurj "$w/dur.tsv" 3 fx1 1000 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4 --history "$w/hbig"; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pool 4 history for fx1: 0 usable, 3 not comparable (0 count outside +-25%, 3 legacy, 0 malformed)' <<<"$out" || return 1
  grep -qF 'recorded: pool 4 pole fx1 1000s' <<<"$out" || return 1
  grep -qF 'RECORDED -- first pole' <<<"$out" && return 1
  hrow5 "$w/hsmall" 4 fx1 100; hrow5 "$w/hsmall" 4 fx1 100; hrow5 "$w/hsmall" 4 fx1 100
  mkdurj "$w/d2.tsv" 3 fx1 1000 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/d2.tsv" --jobs 4 --history "$w/hsmall"; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'recorded: pool 4 pole fx1 1000s' <<<"$out"
}

# (C) A MALFORMED ROW IS NEVER USABLE. Width 4, a full run: three 7-column rows whose load is `abc`
# (count 3) and three 6-column rows, all naming fx1 at 100s. All six are counted `malformed`, the run
# falls to its seed at width 4 (fx1 900) and records (malformed rows count toward nothing, admission
# included). Read as usable, the `abc` rows give B = 100 and 900 FAILS.
arm_malformed_never_usable() {
  local w="$1" out i
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 900 15 4 3 || return 1
  for i in 1 2 3; do printf '4\tfx1\t100\t3\t1\tabc\t3\n' >> "$DRIVE_HIST"; done
  for i in 1 2 3; do printf '4\tfx1\t100\t3\t1\t800\n' >> "$DRIVE_HIST"; done
  mkdurj "$w/dur.tsv" 3 fx1 900 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pool 4 history for fx1: 0 usable, 6 not comparable (0 count outside +-25%, 0 legacy, 6 malformed)' <<<"$out" || return 1
  grep -qF 'recorded: pool 4 pole fx1 900s' <<<"$out"
}

# A GHOST ROW IN THE RECORD IS NOT WORK THIS RUN FAILED TO DO. The hook's merge keeps a key for
# a deleted fixture forever; a 100000s ghost in the denominator would print a full dispatch as
# 11.68% of the record. Joined to the directories on disk the printed share is 100.00%, and the
# grown pole FAILS. The share decides nothing now, so the printed figure is the assertion.
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
  grep -qF 'coverage 100.00%' <<<"$out" || return 1
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

# (iii) ONE UNIT'S HISTORY DOES NOT AFFECT ANOTHER UNIT'S VERDICT (per-unit comparator). Width 4 on a
# 12-fixture tree, every row from an 11-unit dispatch: three name fx1 at 100s, three name fx2 at 500s.
#   run A, fx1 300 beside fx2 at 5 and nine units: compared against fx1's own 100 only -- FAIL GROWN.
#     Against a width-wide B the fx2 rows give 500 and 300 passes: another unit's figure acquits it.
#   run B, fx2 600 beside fx1 at 5: compared against fx2's own 500 (ceiling 665) -- passes, and the
#     line names fx2's baseline, never fx1's.
#   run C, fx3 -- a unit with NO rows of its own -- at 1100: CALIBRATES for fx3 and RECORDS. The regime
#     ceiling is per (width, unit): the width holds six rows whose max is 500 (ceiling 1000), but none is
#     fx3's, so fx3 has no ceiling yet. Counted per WIDTH, 1100 would FAIL GROWN (regime).
# 300 is over half of 500, so the lower-the-baseline NOTE stays silent on every run. Each run reads its
# own copy of the seeded history, so what one run writes is not read by the next.
arm_pole_absent() {
  local w="$1" out rc_a rc_b rc_c
  mktree "$w" 12 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 12 || return 1
  hrow7 "$w/h" 4 fx1 100 11 1000; hrow7 "$w/h" 4 fx1 100 11 1000; hrow7 "$w/h" 4 fx1 100 11 1000
  hrow7 "$w/h" 4 fx2 500 11 1000; hrow7 "$w/h" 4 fx2 500 11 1000; hrow7 "$w/h" 4 fx2 500 11 1000
  cp "$w/h" "$w/ha" && cp "$w/h" "$w/hb" && cp "$w/h" "$w/hc" || return 1
  { printf 'fx1 300\nfx2 5\n'; units 4 9 100 | tr ' ' '\n' | grep . | tr ':' ' '; } > "$w/a.tsv" || return 1
  cp "$w/a.tsv" "$w/a.tsv.rec" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/a.tsv" --jobs 4 --history "$w/ha"; out="$OUT"; rc_a=$RC
  grep -qF 'GROWN: fx1 at 300s against baseline fx1 at 100s' <<<"$out" || return 1
  { printf 'fx2 600\nfx1 5\n'; units 4 9 100 | tr ' ' '\n' | grep . | tr ':' ' '; } > "$w/b.tsv" || return 1
  cp "$w/b.tsv" "$w/b.tsv.rec" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/b.tsv" --jobs 4 --history "$w/hb"; out="$OUT"; rc_b=$RC
  grep -qF 'pole fx2 600s against baseline fx2 500s' <<<"$out" || return 1
  { printf 'fx3 1100\nfx1 5\nfx2 5\n'; units 4 8 100 | tr ' ' '\n' | grep . | tr ':' ' '; } > "$w/c.tsv" || return 1
  cp "$w/c.tsv" "$w/c.tsv.rec" || return 1
  printf '4\n' > "$w/c.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/c.tsv" --jobs 4 --history "$w/hc"; out="$OUT"; rc_c=$RC
  grep -qF 'CALIBRATING (1/3) for fx3' <<<"$out" || return 1
  grep -qF 'recorded: pool 4 pole fx3 1100s' <<<"$out" || return 1
  [ "$rc_a" -eq 1 ] && [ "$rc_b" -eq 0 ] && [ "$rc_c" -eq 0 ]
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

# ONE ROW PER POOL WIDTH. A seed baseline with a block at width 12 (fx1 950) and one at width 16
# (fx1 2000), no history, driven with the same 1000s pole at three widths:
#   --jobs 16 compares against the SECOND block (`baseline fx1 2000s`) -- a first-row reader fails;
#   --jobs 12 compares against the FIRST (`baseline fx1 950s`) -- a last-row reader fails;
#   --jobs 4  has no row and no history and CALIBRATES at exit 0 -- never a FAIL, and never the
#             SKIP it printed before BL-465, which read exactly like a pass.
# Both compared figures keep 1000 inside the band, so this arm never reaches the seed-above-ceiling
# path, which tracked_seed owns.
arm_jobs_mismatch() {
  local w="$1" out rc16 rc12 rc4
  mktree "$w" 3 || return 1
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 950\n# band: 15\n# jobs: 16\n# fixtures: 3\nfx1 2000\n' > "$w/base.tsv" || return 1
  mkdur "$w/dur.tsv" 3 fx1 1000 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 16; out="$OUT"; rc16=$RC
  grep -qF 'against baseline fx1 2000s' <<<"$out" || return 1
  grep -qF 'pool 16' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"; rc12=$RC
  grep -qF 'against baseline fx1 950s' <<<"$out" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"; rc4=$RC
  # Exit 0 with no growth reported: a width with no row is never a FAIL. WHAT it prints instead
  # (CALIBRATING) is history_first_record's to own; asserting it here too would make this arm die
  # beside that one on every no-row mutant and leave neither owning the case.
  grep -qF 'GROWN' <<<"$out" && return 1
  [ "$rc16" -eq 0 ] && [ "$rc12" -eq 0 ] && [ "$rc4" -eq 0 ]
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

# WIDTH SELECTION IS EXACT INTEGER EQUALITY. `--jobs 2` against rows at 12 and 16 has no row: a
# substring or regex match selects 12 alone, and a pool of two compared against a twelve-way loaded
# figure reads as a dramatic improvement. With no row it CALIBRATES; selected wrongly it prints a
# comparison against row 12 instead. Width 2, not 1: a regex `1` matches BOTH rows, and a two-line
# selection names no single unit, so the per-unit seed check would calibrate it too and the arm could
# not see the mutant. The near-miss is `--jobs 12` selecting row 12.
arm_width_exact() {
  local w="$1" out rc1 rc12
  mktree "$w" 3 || return 1
  printf '# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\n# band: 15\n# jobs: 16\n# fixtures: 3\nfx1 200\n' > "$w/base.tsv" || return 1
  mkdur "$w/dur.tsv" 3 fx1 100 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 2; out="$OUT"; rc1=$RC
  # --jobs 1 selects NO tracked row, so it calibrates -- asserted by its words, because a regex
  # selector picks BOTH rows and dies in the arithmetic without ever printing a comparison.
  grep -qF 'CALIBRATING (1/3) for fx1 -- pool width 2 has 0 usable history row(s) for it and no tracked seed names it' <<<"$out" || return 1
  grep -qF 'against baseline' <<<"$out" && return 1
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
  grep -qF 'lower the baseline' <<<"$out" || return 1
  # THE NEAR-MISS, one property apart: a figure just OVER half the baseline gets no note and
  # still exits 0. Without it, an implementation printing the note unconditionally passes.
  mkdur "$w/near.tsv" 3 fx1 501 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/near.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'lower the baseline' <<<"$out" && return 1
  return 0
}

# (i) AN UNCHANGED HEAVY UNIT NEWLY DISPATCHED AT THE SAME COUNT DOES NOT FAIL -- the adversary's
# measured shape on the real 0.760.0 `.last`. Width 4 on a 12-fixture tree, three producer runs of fx1
# 150 beside ten units at 100 (11 dispatched). Then a keyed run at the SAME count drops its cheapest
# unit and dispatches fx12, unchanged, at its usual 1132s: fx12 is now the pole and nothing grew. It
# CALIBRATES for fx12 at exit 0 -- compared against a width-wide B (fx1's 150, ceiling 200) it FAILS
# GROWN, which is the false red this arm forbids. Its row is recorded under fx12's own name.
arm_pole_moved() {
  local w="$1" out i
  mktree "$w" 12 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 12 || return 1
  for i in 1 2 3; do prun "$w" 4 fx1:150 $(units 2 10 100) || return 1; done
  prun "$w" 4 fx1:150 $(units 2 9 100) fx12:1132 || return 1; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'CALIBRATING (1/3) for fx12' <<<"$out" || return 1
  grep -qF 'GROWN' <<<"$out" && return 1
  grep -qF 'recorded: pool 4 pole fx12 1132s' <<<"$out"
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
  # A SEED AT THE DRIVEN WIDTH: this arm's history is an unreadable directory, so the seed is the
  # only comparison it can print, and it is the one it has always printed.
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdur "$w/dur.tsv" 3 fx1 105 || return 1
  # THE HISTORY IS A DIRECTORY, deliberately, and the same one all three times. This arm owns
  # invariance across cwd, not recording: an appendable history would gain a row per run under any
  # mutant that records here, and the next run's output would then differ for a reason another arm
  # owns. A directory cannot be appended to, so every run says the same thing whatever it decides.
  mkdir -p "$w/histdir" || return 1
  o_root="$( bash "$SUBJ" --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12 --record "$w/dur.tsv.rec" --history "$w/histdir" 2>&1 )"; r_root=$?
  o_sub="$( cd "$w/core/fixtures/fx1" && bash "$SUBJ" --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12 --record "$w/dur.tsv.rec" --history "$w/histdir" 2>&1 )"; r_sub=$?
  o_slash="$( cd / && bash "$SUBJ" --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12 --record "$w/dur.tsv.rec" --history "$w/histdir" 2>&1 )"; r_slash=$?
  [ "$r_root" -eq 0 ] && [ "$r_sub" -eq 0 ] && [ "$r_slash" -eq 0 ] || return 1
  # IDENTICAL VERDICT, not merely three zeros: three runs that all printed nothing would be
  # three equal exits. The verdict line itself has to match, and it has to be the real one.
  grep -qF 'pole fx1 105s' <<<"$o_root" || return 1
  [ "$o_root" = "$o_sub" ] || return 1
  [ "$o_root" = "$o_slash" ] || return 1
}

# =======================================================================================
# THE HISTORY ARMS (BL-465). Every pool width records its own pole and is compared against its
# own history; a tracked row only seeds a width that has none. Each arm below drives the subject
# with `--history "$DRIVE_HIST"` (a file in the arm's own directory) and a width sidecar written by
# `mkdurj`, which is what the hook leaves beside a green pool's durations file. All on 3-fixture
# trees, pole fx1, `# history-band: 33` (from mkbase), tracked row only at width 12 unless stated.
# =======================================================================================

# A1. THE FIRST RUN AT AN UNCALIBRATED WIDTH RECORDS, AND THE ROW IS THE PRODUCER'S FORMAT. Width 4,
# no history: exit 0, `RECORDED -- first pole at pool width 4: 100s (fx1)`, and the history holds
# EXACTLY one row reading `4 TAB fx1 TAB 100 TAB 3 TAB <epoch> TAB <load> TAB 3` -- seven fields, the
# last the dispatched count. The load's VALUE is load_excludes_pole's to own (it prints it); here it
# need only be an integer, so a mutant mis-computing L moves that arm and not this one.
arm_history_first_record() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdurj "$w/dur.tsv" 3 fx1 100 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'RECORDED -- first pole at pool width 4: 100s (fx1)' <<<"$out" || return 1
  # And it is CALIBRATING for want of a row at THIS width -- not a seed borrowed from another width.
  grep -qF 'CALIBRATING (1/3) for fx1 -- pool width 4 has 0 usable history row(s) for it and no tracked seed names it' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 1 ] || return 1
  awk -F'\t' 'NF == 7 && $1 == "4" && $2 == "fx1" && $3 == "100" && $4 == "3" && $5 ~ /^[0-9]+$/ && $6 ~ /^[0-9]+$/ && $7 == "3" { ok = 1 } END { exit !ok }' "$DRIVE_HIST"
}

# A2+A3. A RECORDED ROW IS READ, IN BOTH DIRECTIONS. Width 4 history 100/100/100: B = 100, band 33,
# ceiling 133. 1000 FAILS naming GROWN, the history file and the exact drop command; 120 PASSES
# against `baseline fx1 100s (band 33%, ceiling 133s, pool 4)`. The tracked row is at width 12, so a
# subject that never reads history calibrates both runs and passes the grown one.
arm_history_compare() {
  local w="$1" out rc_grown rc_within
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100
  # EACH RUN READS ITS OWN COPY OF THE SEEDED HISTORY. This arm owns the READ; what one run writes
  # is owned by the admission, fail and write-shape arms, and a shared file would let a mutant of
  # any of those (record-on-fail, admit-above-B, a truncating write) move this arm too.
  cp "$DRIVE_HIST" "$w/hist.ok" && cp "$DRIVE_HIST" "$w/hist.big" || return 1
  mkdurj "$w/ok.tsv" 3 fx1 120 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/ok.tsv" --jobs 4 --history "$w/hist.ok"; out="$OUT"; rc_within=$RC
  grep -qF 'source: history' <<<"$out" || return 1
  grep -qF 'pole fx1 120s against baseline fx1 100s (band 33%, ceiling 133s, pool 4)' <<<"$out" || return 1
  mkdurj "$w/big.tsv" 3 fx1 1000 4 || return 1
  DRIVE_HIST="$w/hist.big"
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/big.tsv" --jobs 4; out="$OUT"; rc_grown=$RC
  grep -qF 'GROWN: fx1 at 1000s against baseline fx1 at 100s (band 33%, ceiling 133s, pool 4' <<<"$out" || return 1
  grep -qF "the recorded history at pool 4 in $DRIVE_HIST" <<<"$out" || return 1
  # The command names this width and this file; HOW the path is quoted is drop_command_quoted's.
  grep -qF "awk -F'\\t' -v w=4 '\$1 != w'" <<<"$out" || return 1
  grep -qF "$DRIVE_HIST.new" <<<"$out" || return 1
  [ "$rc_grown" -eq 1 ] && [ "$rc_within" -eq 0 ]
}

# A4 / B1. WIDTH 12 WITH A TRACKED ROW AND NO HISTORY IS A CALIBRATING SEED. Within its band the
# comparison line is byte-identical to the pre-BL-465 one; the source is named as the SEED; and the
# run RECORDS. ABOVE its ceiling it is reported (ABOVE SEED), recorded and passed -- exit 0, never
# GROWN -- because the operator ruled the hand-calibrated rows the defect and a seed that could FAIL
# would stop the history that replaces it from forming. Two figures, one property apart.
arm_tracked_seed() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdurj "$w/dur.tsv" 3 fx1 105 12 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qxF '   pole fx1 105s against baseline fx1 100s (band 15%, ceiling 115s, pool 12)' <<<"$out" || return 1
  grep -qF 'CALIBRATING (1/3) for fx1 -- source: the tracked SEED row for pool 12' <<<"$out" || return 1
  grep -qF 'recorded: pool 12 pole fx1 105s' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 1 ] || return 1
  mkdurj "$w/big.tsv" 3 fx1 1000 12 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/big.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'ABOVE SEED  fx1 at 1000s is above the tracked seed fx1 at 100s (band 15%, ceiling 115s, pool 12)' <<<"$out" || return 1
  grep -qF 'GROWN' <<<"$out" && return 1
  # Asserted on the subject's own words, not a second row count: whether an append ADDS a line is
  # history_admission's to own, and a count here would move under the truncating-write mutant too.
  grep -qF 'recorded: pool 12 pole fx1 1000s' <<<"$out"
}

# A5. NO MEASUREMENT RECORDS NOTHING, even with a matching sidecar beside the empty file -- the
# state a red pool leaves. The near-miss in the same arm: a measurement records. Both at width 12,
# where the tracked row is the source, so the near-miss does not depend on how a width with no row
# is handled -- history_first_record owns that.
arm_no_measurement_writes_nothing() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  : > "$w/empty.tsv" || return 1
  printf '12\n' > "$w/empty.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/empty.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'SKIP -- no fresh full-suite measurement' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST")" -eq 0 ] || return 1
  mkdurj "$w/dur.tsv" 3 fx1 100 12 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 1 ]
}

# (g) A KEYED RUN WITH A LOW SHARE OF THE RECORD NOW RECORDS (BL-465). Width 4, no history, 2 of 3
# units timed -- fx1 60 and fx2 35 of a 140s record, a 67.85% share, the shape a real keyed push
# measured. Before the load design this SKIPped on coverage and no keyed push could ever record; now
# it CALIBRATES, prints the share, and appends one row whose dispatched column is 2. The row's load
# VALUE is load_excludes_pole's to own; here only the row and its dispatched count are asserted.
#
# THE SEED IS AT THE DRIVEN WIDTH, so the run is a seed calibration and not the no-row path: how a
# width with no row is handled (and which row a selector picks) is history_first_record's and
# jobs_mismatch's, and this arm owns only that a low share no longer stops the record.
arm_low_share_records() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 4 3 || return 1
  printf 'fx1 60\nfx2 35\nfx3 45\n' > "$w/rec.tsv" || return 1
  printf 'fx1 60\nfx2 35\n' > "$w/keyed.tsv" || return 1
  printf '4\n' > "$w/keyed.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/keyed.tsv" --record "$w/rec.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'recorded: pool 4 pole fx1 60s' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 1 ] || return 1
  awk -F'\t' 'NF == 7 && $1 == "4" && $2 == "fx1" && $7 == "2" { ok = 1 } END { exit !ok }' "$DRIVE_HIST"
}

# (a) THE RECORDED LOAD EXCLUDES THE POLE BY NAME, AND A GROWN UNIT FAILS AGAINST ITS OWN ROWS, on rows
# the validator WRITES. Width 4: three producer runs of fx2 100 beside fx1 5 and fx3 90 calibrate fx2,
# each recording load 95 (fx1 + fx3, the pole fx2 left out). Then fx2 grows to 1000s: same three units,
# fx2's own rows are usable, B = 100, and it FAILS GROWN with the printed load 95. The load decides
# nothing; this arm owns its VALUE, in the row and on the line. (A unit that grows AND becomes the pole
# for the first time is the irreducible acquittal in the validator's header, and is not asserted here.)
arm_load_excludes_pole() {
  local w="$1" out i
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  for i in 1 2 3; do prun "$w" 4 fx1:5 fx2:100 fx3:90 || return 1; [ "$RC" -eq 0 ] || return 1; done
  [ "$(awk -F'\t' '$2 == "fx2" && $6 == "95" && $7 == "3"' "$DRIVE_HIST" | grep -c .)" -eq 3 ] || return 1
  prun "$w" 4 fx1:5 fx2:1000 fx3:90 || return 1; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF "dispatched 3 fixture directories (load 95s, this run's on-disk cost less its pole fx2, printed only); pool 4 history for fx2: 3 usable, 0 not comparable" <<<"$out" || return 1
  grep -qF 'GROWN: fx2 at 1000s against baseline fx2 at 100s' <<<"$out"
}

# (A) A ROW WHOSE DISPATCHED COUNT IS OUT OF BAND IS NOT COMPARABLE. Width 4, three rows naming fx1 at
# 1500s from a 20-unit dispatch; this run dispatches 3 (fx1 2000). 20 is above 125% of 3, so all three
# are counted out of band, no history is usable, and the run falls to its tracked seed AT width 4
# (fx1 2000, so 2000 is inside it) -- compared, exit 0. 2000 is inside the regime ceiling over fx1's max
# (1500 + 100% = 3000), so that is not what decides it. Compared without the band, B = 1500, ceiling
# 1995, and 2000 would FAIL GROWN -- which is how this arm owns the band itself.
arm_count_out_of_band() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 2000 15 4 3 || return 1
  hrow7 "$DRIVE_HIST" 4 fx1 1500 20 4000; hrow7 "$DRIVE_HIST" 4 fx1 1500 20 4000; hrow7 "$DRIVE_HIST" 4 fx1 1500 20 4000
  printf 'fx1 2000\nfx2 1500\nfx3 1500\n' > "$w/dur.tsv" || return 1
  cp "$w/dur.tsv" "$w/dur.tsv.rec" || return 1
  printf '4\n' > "$w/dur.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pool 4 history for fx1: 0 usable, 3 not comparable (3 count outside +-25%' <<<"$out" || return 1
  grep -qF 'GROWN' <<<"$out" && return 1
  return 0
}

# (A) THE BAND IS INCLUSIVE AT BOTH EDGES, AND AN IN-BAND HISTORY ENFORCES. Width 4 on a 4-fixture tree,
# three rows naming fx1 at 100s from dispatches of 3, 4 and 5 units -- exactly -25%, 0 and +25% of this
# run's 4. All three are usable: fx1 at 1000s FAILS GROWN against B = 100. An exclusive edge drops one
# row, leaves two, and CALIBRATES the grown pole at exit 0. The near-miss in the same arm: fx1 at 120s
# (each run reads its own copy of the seeded history) is compared and passes inside the ceiling of 133.
arm_count_in_band() {
  local w="$1" out rc_grown rc_ok
  mktree "$w" 4 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 4 || return 1
  hrow7 "$w/h" 4 fx1 100 3 150; hrow7 "$w/h" 4 fx1 100 4 150; hrow7 "$w/h" 4 fx1 100 5 150
  cp "$w/h" "$w/h.big" && cp "$w/h" "$w/h.ok" || return 1
  printf 'fx1 1000\nfx2 50\nfx3 50\nfx4 50\n' > "$w/big.tsv" || return 1
  cp "$w/big.tsv" "$w/big.tsv.rec" || return 1
  printf '4\n' > "$w/big.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/big.tsv" --jobs 4 --history "$w/h.big"; out="$OUT"; rc_grown=$RC
  grep -qF 'pool 4 history for fx1: 3 usable, 0 not comparable' <<<"$out" || return 1
  grep -qF 'GROWN: fx1 at 1000s against baseline fx1 at 100s' <<<"$out" || return 1
  printf 'fx1 120\nfx2 50\nfx3 50\nfx4 50\n' > "$w/ok.tsv" || return 1
  cp "$w/ok.tsv" "$w/ok.tsv.rec" || return 1
  printf '4\n' > "$w/ok.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/ok.tsv" --jobs 4 --history "$w/h.ok"; out="$OUT"; rc_ok=$RC
  grep -qF 'pole fx1 120s against baseline fx1 100s (band 33%, ceiling 133s, pool 4)' <<<"$out" || return 1
  [ "$rc_grown" -eq 1 ] && [ "$rc_ok" -eq 0 ]
}

# (E) PRODUCER-SEQUENTIAL: the validator writes its own history over consecutive runs, never seeded by
# hand, and each recorded row changes the next run's verdict. Width 4 on a 3-fixture tree (seed only at
# width 12), full dispatches unless stated; row counts are fx1's rows (every run also records fx2, fx3):
#   1-3  fx1 100 three times: RECORDED as the first pole, then CALIBRATING (2/3) and (3/3), each recorded;
#   4    fx1 200: run 3's row is what makes K -- with two rows this would calibrate -- so it FAILS GROWN;
#   5    fx1 90: compared against B = 100 and admitted, four fx1 rows;
#   6    a keyed run timing fx1 alone at 180s: a 1-unit dispatch is out of band of 3, and 180 is inside
#        the regime ceiling over fx1's max (100 + 100% = 200) -- it calibrates and is recorded, five;
#   7    fx1 alone again at 400s: one comparable row (the 180), fewer than K, and 400 is past the regime
#        ceiling over fx1's max 180 (360) -- FAIL GROWN (regime), still five;
#   8    fx1 300, full dispatch: FAILS GROWN against fx1's own count-3 rows -- runs 6 and 7 laundered
#        nothing into them.
arm_producer_sequential() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  prun "$w" 4 fx1:100 fx2:50 fx3:50 || return 1; out="$OUT"
  grep -qF 'RECORDED -- first pole at pool width 4: 100s (fx1)' <<<"$out" || return 1
  prun "$w" 4 fx1:100 fx2:50 fx3:50 || return 1; grep -qF 'CALIBRATING (2/3)' <<<"$OUT" || return 1
  prun "$w" 4 fx1:100 fx2:50 fx3:50 || return 1; grep -qF 'CALIBRATING (3/3)' <<<"$OUT" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 3 ] || return 1
  prun "$w" 4 fx1:200 fx2:50 fx3:50 || return 1; out="$OUT"
  [ "$RC" -eq 1 ] && grep -qF 'GROWN: fx1 at 200s against baseline fx1 at 100s' <<<"$out" || return 1
  prun "$w" 4 fx1:90 fx2:50 fx3:50 || return 1
  [ "$RC" -eq 0 ] && [ "$(hlines "$DRIVE_HIST" fx1)" -eq 4 ] || return 1
  prun "$w" 4 fx1:180 || return 1; out="$OUT"
  [ "$RC" -eq 0 ] && grep -qF 'CALIBRATING (1/3) for fx1' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 5 ] || return 1
  prun "$w" 4 fx1:400 || return 1; out="$OUT"
  [ "$RC" -eq 1 ] && grep -qF 'GROWN (regime): fx1 at 400s against its own max 180s' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 5 ] || return 1
  # The verdict, not B's figure: which row B is (the max, not the last) is history_statistic's.
  prun "$w" 4 fx1:300 fx2:50 fx3:50 || return 1
  [ "$RC" -eq 1 ] && grep -qF 'GROWN: fx1 at 300s against baseline fx1 at' <<<"$OUT"
}

# (E / shape 1) A UNIFORM SLOWDOWN IS STILL COMPARED. Width 4 on a 12-fixture tree, three producer runs
# of fx1 150 beside ten units at 100 (11 units, load 1000). Then every unit 40% slower -- fx1 210, the
# ten at 140: the dispatch is the same 11 units, so the rows stay usable, and 210 is over the ceiling
# of 200 -- FAIL GROWN. Keyed on load, 1000 is out of band of 1400 and the regression calibrates.
arm_uniform_slowdown() {
  local w="$1" out i
  mktree "$w" 12 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 12 || return 1
  for i in 1 2 3; do prun "$w" 4 fx1:150 $(units 2 10 100) || return 1; done
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 3 ] || return 1
  prun "$w" 4 fx1:210 $(units 2 10 140) || return 1; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'GROWN: fx1 at 210s against baseline fx1 at 150s' <<<"$out"
}

# (E / shape 2) A REGRESSION AT A NOVEL DISPATCH COUNT IS JUDGED BY THE REGIME CEILING. Width 4 on an
# 18-fixture tree, three producer runs of fx1 150 beside ten units (11 dispatched). fx1 600 beside
# sixteen units, 17 dispatched, out of band of 11: fx1 has 3 rows and none comparable, and 600 is past
# its max 150 plus 100% (300) -- FAIL GROWN (regime), nothing recorded. Under the old FROZEN state that
# passed at exit 0. Then fx1 280 at 17 units, inside the ceiling: calibrates and is recorded -- the
# stated acquittal (under 2x at a new count is admitted once). Then fx1 700 at 14 units, in band of both
# 11 and 17: compared against fx1's own rows, B = 280, ceiling 373 -- FAIL GROWN.
arm_launder_novel_count() {
  local w="$1" out i
  mktree "$w" 18 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 18 || return 1
  for i in 1 2 3; do prun "$w" 4 fx1:150 $(units 2 10 100) || return 1; done
  prun "$w" 4 fx1:600 $(units 2 16 100) || return 1; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'GROWN (regime): fx1 at 600s against its own max 150s over 3 row(s) at pool 4' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 3 ] || return 1
  prun "$w" 4 fx1:280 $(units 2 16 100) || return 1
  [ "$RC" -eq 0 ] && [ "$(hlines "$DRIVE_HIST" fx1)" -eq 4 ] || return 1
  prun "$w" 4 fx1:700 $(units 2 13 100) || return 1; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'GROWN: fx1 at 700s against baseline fx1 at 280s' <<<"$out"
}

# (E / shape 3) A KEYED RUN THAT SKIPS fx1 IS JUDGED ON ITS OWN POLE'S ROWS. Width 4 on a 12-fixture
# tree, three producer runs of fx1 150 beside ten units at 100 -- which, under option (a), also records
# fx2..fx11 at 100. A keyed run that does not dispatch fx1, fx2 grown to 600 at the same count: fx2's
# own rows are comparable, B = 100 -- FAIL GROWN against fx2. (With pole-only rows fx2 had none and
# calibrated at 600.) The next run, fx1 grown to 210 beside nine units, FAILS against fx1's own 150:
# nothing the keyed run did reached fx1's baseline.
arm_keyed_skip_launder() {
  local w="$1" out i
  mktree "$w" 12 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 12 || return 1
  for i in 1 2 3; do prun "$w" 4 fx1:150 $(units 2 10 100) || return 1; done
  prun "$w" 4 fx2:600 $(units 3 10 100) || return 1; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'GROWN: fx2 at 600s against baseline fx2 at 100s' <<<"$out" || return 1
  prun "$w" 4 fx1:210 $(units 3 10 100) || return 1; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'GROWN: fx1 at 210s against baseline fx1 at 150s' <<<"$out"
}

# (R1-cross) THE REGIME CEILING, replacing FROZEN. Width 4 on a 40-fixture tree, three keyed producer runs
# of fx2 100 beside nine units at 50 (10 dispatched). Each later run reads its own copy of that history:
#   grow   a full dispatch (40), fx2 at 1000: fx2 has 3 rows, none comparable, 1000 is past its max 100
#          plus 100% (200) -- FAIL GROWN (regime), naming the max and its row count. Nothing appended.
#   edge   exactly the ceiling, fx2 200 at 40: passes and calibrates; 201: FAIL GROWN (regime).
#   shift  every unit 1.5x at 40 -- fx2 150, the rest 75, strictly inside the band: records all 40 units
#          (the new count range calibrates its own history), and the NEXT count-40 run compares fx2
#          against that row: CALIBRATING (2/3) against its max so far 150s.
arm_regime_ceiling() {
  local w="$1" out i h
  mktree "$w" 40 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 40 || return 1
  for i in 1 2 3; do prun "$w" 4 fx2:100 $(units 3 9 50) || return 1; done
  h="$DRIVE_HIST"
  [ "$(hlines "$h" fx2)" -eq 3 ] || return 1
  cp "$h" "$w/h.grow" && cp "$h" "$w/h.e200" && cp "$h" "$w/h.e201" && cp "$h" "$w/h.shift" || return 1
  DRIVE_HIST="$w/h.grow"
  prun "$w" 4 fx1:50 fx2:1000 $(units 3 38 50) || return 1; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'GROWN (regime): fx2 at 1000s against its own max 100s over 3 row(s) at pool 4' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST")" -eq 30 ] || return 1
  DRIVE_HIST="$w/h.e200"
  prun "$w" 4 fx1:50 fx2:200 $(units 3 38 50) || return 1; out="$OUT"
  [ "$RC" -eq 0 ] && grep -qF 'CALIBRATING (1/3) for fx2' <<<"$out" || return 1
  DRIVE_HIST="$w/h.e201"
  prun "$w" 4 fx1:50 fx2:201 $(units 3 38 50) || return 1
  [ "$RC" -eq 1 ] && grep -qF 'GROWN (regime): fx2 at 201s' <<<"$OUT" || return 1
  DRIVE_HIST="$w/h.shift"
  prun "$w" 4 fx1:75 fx2:150 $(units 3 38 75) || return 1; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'units: 40 row(s) appended of 40 dispatched unit(s) at pool 4; 0 refused' <<<"$out" || return 1
  prun "$w" 4 fx1:75 fx2:150 $(units 3 38 75) || return 1; out="$OUT"
  grep -qF 'CALIBRATING (2/3) for fx2 -- pool width 4 has 1 usable history row(s) for it and no tracked seed names it; pole fx2 150s against its max so far 150s' <<<"$out"
}

# (R1) A NON-POLE UNIT THAT GROWS INTO THE POLE IS JUDGED AGAINST ITS OWN EARLIER ROWS -- the hole option
# (a) closes. Width 4 on a 3-fixture tree, producer-written: three runs with fx1 the pole at 200 and fx2
# dispatched beside it at 100. fx2 then grows to 1000 and becomes the pole: FAIL GROWN against fx2's own
# 100. Recording only each run's pole, fx2 would have no rows, calibrate at 1000, and keep it as its B.
arm_grown_into_pole() {
  local w="$1" i
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  for i in 1 2 3; do prun "$w" 4 fx1:200 fx2:100 fx3:50 || return 1; [ "$RC" -eq 0 ] || return 1; done
  prun "$w" 4 fx1:200 fx2:1000 fx3:50 || return 1
  [ "$RC" -eq 1 ] && grep -qF 'GROWN: fx2 at 1000s against baseline fx2 at 100s' <<<"$OUT"
}

# (R3) fx2's ROWS COME FROM RUNS WITH fx1 ABSENT AND PRESENT ALIKE, and a keyed run without fx1 is judged
# by all of them. Width 4 on a 4-fixture tree: fx2 at 100 dispatched beside fx1 (fx1 the pole), then
# without fx1 (fx2 the pole), then beside fx1 again -- three units each time. A keyed run with fx1
# absent and fx2 at 900: FAIL GROWN against fx2's own 100.
arm_grown_keyed_absent() {
  local w="$1"
  mktree "$w" 4 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 4 || return 1
  prun "$w" 4 fx1:200 fx2:100 fx3:50 || return 1
  prun "$w" 4 fx2:100 fx3:50 fx4:50 || return 1
  prun "$w" 4 fx1:200 fx2:100 fx3:50 || return 1
  [ "$(hlines "$DRIVE_HIST" fx2)" -eq 3 ] || return 1
  prun "$w" 4 fx2:900 fx3:50 fx4:50 || return 1
  [ "$RC" -eq 1 ] && grep -qF 'GROWN: fx2 at 900s against baseline fx2 at 100s' <<<"$OUT"
}

# NON-POLE GROWTH IS ADMITTED ONLY BY ITS OWN ADMISSION. Width 4, three producer runs of fx1 200, fx2
# 100, fx3 50. Then fx3 -- never the pole -- at 80: the run passes on fx1, and fx3's row is NOT appended
# (80 is above fx3's own B of 50); the summary line counts it and names it. Then fx3 at 45: appended.
arm_nonpole_admission() {
  local w="$1" out i
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  for i in 1 2 3; do prun "$w" 4 fx1:200 fx2:100 fx3:50 || return 1; done
  prun "$w" 4 fx1:200 fx2:100 fx3:80 || return 1; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'units: 2 row(s) appended of 3 dispatched unit(s) at pool 4; 1 refused above their own baseline (highest: fx3 80s vs 50s)' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx3)" -eq 3 ] || return 1
  prun "$w" 4 fx1:200 fx2:100 fx3:45 || return 1
  [ "$(hlines "$DRIVE_HIST" fx3)" -eq 4 ]
}

# ONE RUN APPENDS EXACTLY ONE ROW PER ON-DISK DISPATCHED UNIT. A first run on a 3-fixture tree whose
# durations also name `fx-ghost` (no directory): three rows, one each for fx1, fx2, fx3, none for the
# ghost, and columns 4-7 (fixtures, epoch, load, dispatched) identical across the run's rows.
arm_rows_per_unit() {
  local w="$1"
  mktree "$w" 3 || return 1
  [ -d "$w/core/fixtures/fx-ghost" ] && return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  prun "$w" 4 fx1:100 fx2:60 fx3:40 fx-ghost:9 || return 1
  [ "$RC" -eq 0 ] || return 1
  [ "$(hlines "$DRIVE_HIST")" -eq 3 ] || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 1 ] && [ "$(hlines "$DRIVE_HIST" fx2)" -eq 1 ] && [ "$(hlines "$DRIVE_HIST" fx3)" -eq 1 ] || return 1
  [ "$(hlines "$DRIVE_HIST" fx-ghost)" -eq 0 ] || return 1
  [ "$(awk -F'\t' '{ print $4, $5, $6, $7 }' "$DRIVE_HIST" | sort -u | grep -c .)" -eq 1 ]
}

# THE APPEND SITE IS PINNED: exactly one `printf '%s' "$ROWS" >` writes the history and it names
# "$HIST", and the awk program that builds the rows (unit_rows) redirects nothing. awk appending rows
# directly tore 2-112 lines under two concurrent writers where one shell printf per run tore none
# (measured, see the subject's RECORD POINT header), and no behavioural arm can see the difference in a
# single-writer world -- so this arm reads the subject's text. The function body is located by its own
# definition line, and a body that cannot be found is a failure, never an empty pass.
arm_append_site_pinned() {
  local n body site
  n="$(grep -cF "printf '%s' \"\$ROWS\" >" "$SUBJ")" || n=0
  [ "$n" -eq 1 ] || return 1
  site="$(grep -F "printf '%s' \"\$ROWS\" >" "$SUBJ")" || return 1
  grep -qF '"$HIST"' <<<"$site" || return 1
  body="$(awk '/^unit_rows\(\) \{/ { p = 1 } p { print } p && /^}$/ { exit }' "$SUBJ")"
  grep -qF 'buf = buf sprintf(' <<<"$body" || return 1
  grep -qF '>>' <<<"$body" && return 1
  return 0
}

# (f) A TRACKED SEED IS CONSULTED ONLY FOR THE UNIT IT NAMES. Width 12, seed fx1 100 band 15, no
# history, and a run timing fx2 and fx3 only (fx2 105): fx2 is the pole, the seed names fx1, so the seed
# is not consulted and nothing is printed about it -- the run CALIBRATES for fx2 and RECORDS. A seed
# consulted for another unit would compare fx2 against fx1's figure, the cross-unit comparison the
# per-unit design forbids.
arm_seed_pole_absent_records() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  printf 'fx1 5\nfx2 105\nfx3 100\n' > "$w/rec-in.tsv" || return 1
  printf 'fx2 105\nfx3 100\n' > "$w/in.tsv" || return 1
  printf '12\n' > "$w/in.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/in.tsv" --record "$w/rec-in.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'CALIBRATING (1/3) for fx2 -- pool width 12 has 0 usable history row(s) for it and no tracked seed names it' <<<"$out" || return 1
  grep -qF 'SEED' <<<"$out" && return 1
  grep -qF 'recorded: pool 12 pole fx2 105s' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx2)" -eq 1 ]
}

# A7. A FAIL APPENDS NOTHING. History 100/100/100 at width 4, a 1000s pole: exit 1 and still three
# rows. The near-miss, asserted on the subject's own words rather than a count (a count here would
# also move under the truncating-write mutant, which admission owns): a 100s pole says `recorded:`.
arm_fail_appends_nothing() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100
  mkdurj "$w/big.tsv" 3 fx1 1000 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/big.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  [ "$(hlines "$DRIVE_HIST")" -eq 3 ] || return 1
  mkdurj "$w/ok.tsv" 3 fx1 100 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/ok.tsv" --jobs 4; out="$OUT"
  grep -qF 'recorded: pool 4 pole fx1 100s' <<<"$out"
}

# A8. A WIDTH READS ONLY ITS OWN ROWS. Width 4 rows 100/100/100, then width 8 rows 1000/1000/1000
# written AFTER them. At width 4, B = 100 and ceiling 133, so a 300s pole FAILS. Read without the
# width filter the three most recent rows are width 8's, B = 1000, and 300 passes.
arm_history_width_isolation() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100
  hrow "$DRIVE_HIST" 8 fx1 1000; hrow "$DRIVE_HIST" 8 fx1 1000; hrow "$DRIVE_HIST" 8 fx1 1000
  mkdurj "$w/dur.tsv" 3 fx1 300 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  grep -qF 'against baseline fx1 at 100s (band 33%, ceiling 133s, pool 4' <<<"$out"
}

# A9. THE STATISTIC IS THE MAX OF EVERY USABLE ROW. Width 4 rows, oldest first: 100, 300, 200, 150.
# B = 300, ceiling 300 + ceil(99) = 399, so 290 PASSES against 300.
#   last row (150): ceiling 200, FAILS;   first row (100): ceiling 133, FAILS.
# The max sits inside the 3 most recent on purpose, so a 3-row window reads 300 too and this arm
# does not move under it: the window is history_no_collapse's to own.
arm_history_statistic() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 300; hrow "$DRIVE_HIST" 4 fx1 200; hrow "$DRIVE_HIST" 4 fx1 150
  mkdurj "$w/dur.tsv" 3 fx1 290 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pole fx1 290s against baseline fx1 300s (band 33%, ceiling 399s, pool 4)' <<<"$out" || return 1
  grep -qF 'max of 4 usable row(s) for fx1 at pool 4' <<<"$out"
}

# THE RATCHET MUST NOT COLLAPSE (the K-window defect, measured by the tip adversary). Driven through
# the subject's own writer, in order: calibrate width 4 at 500, 520, 510; then three quiet runs at
# 300, each at or below B and so ADMITTED; then an ordinary loaded 450. Over every row B is 520,
# ceiling 692, and 450 PASSES. Over the 3 most recent rows B fell to 300, ceiling 399, and 450 FAILS
# -- which is what every figure from 410 to 500 did on the defective tip.
arm_history_no_collapse() {
  local w="$1" out s
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  for s in 500 520 510 300 300 300; do
    mkdurj "$w/d$s.tsv" 3 fx1 "$s" 4 || return 1
    drive --root "$w" --baseline "$w/base.tsv" --durations "$w/d$s.tsv" --jobs 4
    [ "$RC" -eq 0 ] || return 1
  done
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 6 ] || return 1
  mkdurj "$w/d450.tsv" 3 fx1 450 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/d450.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pole fx1 450s against baseline fx1 520s (band 33%, ceiling 692s, pool 4)' <<<"$out"
}

# ONE PUBLISHED MEASUREMENT IS ONE ROW. Four invocations over the SAME durations file and sidecar --
# what a re-run gate, or a hand-run validator, does -- give exactly one history row: the first
# recording consumes the sidecar, and the next three each say why they did not record.
arm_sidecar_consumed() {
  local w="$1" out i
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdurj "$w/dur.tsv" 3 fx1 100 4 || return 1
  for i in 1 2 3 4; do
    drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"
    [ "$RC" -eq 0 ] || return 1
  done
  grep -qF 'not recorded: the width sidecar' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 1 ]
}

# THE DROP COMMAND IS PASTEABLE FOR A HISTORY PATH CARRYING A QUOTE. The FAIL text prints the exact
# command the operator is told to run; a hand-quoted `'%s'` splits at a `'` in the path. Here the
# history lives under a directory named `it's`: the printed command is EXECUTED, and it must remove
# width 4's rows and keep width 8's.
arm_drop_command_quoted() {
  local w="$1" out cmd d h
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  d="$w/it's"; mkdir -p "$d" || return 1; h="$d/hist"
  hrow "$h" 4 fx1 100; hrow "$h" 4 fx1 100; hrow "$h" 4 fx1 100; hrow "$h" 8 fx1 100
  mkdurj "$w/big.tsv" 3 fx1 1000 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/big.tsv" --jobs 4 --history "$h"; out="$OUT"
  [ "$RC" -eq 1 ] || return 1
  cmd="$(printf '%s\n' "$out" | sed -n 's/^           awk /awk /p')"
  [ -n "$cmd" ] || return 1
  bash -c "$cmd" >/dev/null 2>&1 || return 1
  [ "$(hlines "$h")" -eq 1 ] && awk -F'\t' '$1 == "8" { ok = 1 } END { exit !ok }' "$h"
}

# A10. THE WIDTH SIDECAR MUST EQUAL --jobs. A durations file whose sidecar reads 4, driven at width
# 12, is a measurement some other pool published: the run is compared and passes, but nothing is
# recorded and the line names the sidecar. A missing sidecar is the same. The near-miss: a sidecar
# reading 12 records. Width 12 against its tracked row throughout, so the arm owns the sidecar and
# nothing about how a width with no row is handled.
arm_sidecar_mismatch() {
  local w="$1" out
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdurj "$w/dur.tsv" 3 fx1 100 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF "not recorded: the width sidecar $w/dur.tsv.jobs reads \"4\", not --jobs 12" <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST")" -eq 0 ] || return 1
  rm -f "$w/dur.tsv.jobs"
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  grep -qF 'reads "", not --jobs 12' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST")" -eq 0 ] || return 1
  printf '12\n' > "$w/dur.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 12; out="$OUT"
  grep -qF 'recorded: pool 12 pole fx1 100s' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 1 ]
}

# A11. A HISTORY ROW WHOSE POLE DIRECTORY IS GONE IS IGNORED, NOT REFUSED. Width 4: fx1 100 x3, then
# the three MOST RECENT rows name `fx-sharded-away` at 1000s. Ignored, B = 100 and 120 passes with a
# NOTE counting three; counted, B = 1000 and the comparison names it. Refused, it would exit 2.
#
# THE RUN TIMES fx-sharded-away TOO (a row for a directory not on disk, which the hook's pool can
# leave in a stale .last). Without it the "pole not timed" test would ALSO exclude these rows, the two
# guards would cover each other, and dropping the gone test would change no comparison.
arm_stale_history_ignored() {
  local w="$1" out
  mktree "$w" 3 || return 1
  [ -d "$w/core/fixtures/fx-sharded-away" ] && return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100
  hrow "$DRIVE_HIST" 4 fx-sharded-away 1000; hrow "$DRIVE_HIST" 4 fx-sharded-away 1000; hrow "$DRIVE_HIST" 4 fx-sharded-away 1000
  printf 'fx1 120\nfx2 1\nfx3 1\nfx-sharded-away 5\n' > "$w/dur.tsv" || return 1
  cp "$w/dur.tsv" "$w/dur.tsv.rec" || return 1
  printf '4\n' > "$w/dur.tsv.jobs" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'pole fx1 120s against baseline fx1 100s (band 33%, ceiling 133s, pool 4)' <<<"$out" || return 1
  grep -qF '3 history row(s) at pool 4 name a pole directory that no longer exists and were ignored' <<<"$out"
}

# A12. AT 12 AND 16, HISTORY OUTRANKS THE TRACKED ROW ONCE IT HOLDS K ROWS -- in both directions.
#   width 12: tracked fx1 100 band 15 (ceiling 115); history 300 x3 (ceiling 399). 200 PASSES and
#             prints the history comparison, not the seed's.
#   width 16: tracked fx1 2000 band 15 (ceiling 2300); history 300 x3 (ceiling 399). 1000 FAILS.
# A subject preferring the seed passes width 16 (a seed never fails) and prints the seed line at 12.
arm_history_precedence() {
  local w="$1" out rc12 rc16
  mktree "$w" 3 || return 1
  printf '# history-band: 33\n# band: 15\n# jobs: 12\n# fixtures: 3\nfx1 100\n# band: 15\n# jobs: 16\n# fixtures: 3\nfx1 2000\n' > "$w/base.tsv" || return 1
  hrow "$DRIVE_HIST" 12 fx1 300; hrow "$DRIVE_HIST" 12 fx1 300; hrow "$DRIVE_HIST" 12 fx1 300
  hrow "$DRIVE_HIST" 16 fx1 300; hrow "$DRIVE_HIST" 16 fx1 300; hrow "$DRIVE_HIST" 16 fx1 300
  # Width 16 FIRST: it fails and records nothing, so the width-12 run reads the seeded file intact.
  mkdurj "$w/d16.tsv" 3 fx1 1000 16 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/d16.tsv" --jobs 16; out="$OUT"; rc16=$RC
  grep -qF 'GROWN: fx1 at 1000s against baseline fx1 at 300s' <<<"$out" || return 1
  mkdurj "$w/d12.tsv" 3 fx1 200 12 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/d12.tsv" --jobs 12; out="$OUT"; rc12=$RC
  grep -qF 'pole fx1 200s against baseline fx1 300s (band 33%, ceiling 399s, pool 12)' <<<"$out" || return 1
  [ "$rc12" -eq 0 ] && [ "$rc16" -eq 1 ]
}

# ADMISSION: ONCE HISTORY IS THE SOURCE, ONLY A POLE AT OR BELOW B IS APPENDED. History 100 x3 at
# width 4: 120 is inside the band (ceiling 133) and above B, so it passes and is NOT recorded --
# three rows stay three. The near-miss: 90 is at or below B and is appended, giving four, which
# also proves each append ADDS a line rather than replacing the file.
arm_history_admission() {
  local w="$1" out rc_above
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100; hrow "$DRIVE_HIST" 4 fx1 100
  mkdurj "$w/above.tsv" 3 fx1 120 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/above.tsv" --jobs 4; out="$OUT"; rc_above=$RC
  grep -qF 'not recorded: 120s is inside the band but above B=100s' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 3 ] || return 1
  mkdurj "$w/below.tsv" 3 fx1 90 4 || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/below.tsv" --jobs 4; out="$OUT"
  grep -qF 'recorded: pool 4 pole fx1 90s' <<<"$out" || return 1
  [ "$(hlines "$DRIVE_HIST" fx1)" -eq 4 ] && [ "$rc_above" -eq 0 ]
}

# NO `--history` ON A ROOT THAT IS NOT A REPOSITORY CREATES NOTHING. The default history lives in
# the git common dir; with none there is no default, no `.git` is made under the probe root, and the
# run says it did not record. The near-miss: the same world after `git init` records into
# `.git/ai-dlc-suite-pole.history` by default.
arm_nonrepo_creates_nothing() {
  local w="$1" out r
  r="$w/r"; mkdir -p "$r" || return 1
  mktree "$r" 3 || return 1
  git -C "$r" rev-parse --git-dir >/dev/null 2>&1 && return 1   # the world must not be inside a repo
  mkseed "$w/base.tsv" fx1 100 15 12 3 || return 1
  mkdurj "$w/dur.tsv" 3 fx1 100 12 || return 1
  out="$(bash "$SUBJ" --root "$r" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --record "$w/dur.tsv.rec" --jobs 12 2>&1)" || return 1
  grep -qF "not recorded: $r is not a git repository and no --history was given" <<<"$out" || return 1
  [ ! -e "$r/.git" ] || return 1
  [ -z "$(find "$w" -name 'ai-dlc-suite-pole.history' 2>/dev/null)" ] || return 1
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; git init -q "$r" ) >/dev/null 2>&1 || return 1
  out="$(bash "$SUBJ" --root "$r" --baseline "$w/base.tsv" --durations "$w/dur.tsv" --record "$w/dur.tsv.rec" --jobs 12 2>&1)" || return 1
  [ "$(hlines "$r/.git/ai-dlc-suite-pole.history" fx1)" -eq 1 ]
}

# D1. UNDER HISTORY THE NOTE NAMES THE DROP COMMAND, NOT THE ROW. Width 4, history fx1 1000 x3 and a
# 90s run: below half of B, so the lower-the-baseline NOTE fires, followed by the drop command for
# pool 4. The near-miss, the SAME NOTE from a SEED (width 12, tracked fx1 1000, no history): no drop
# command, because there is no history to drop and the tracked row is what the operator edits.
arm_notes_name_drop_command() {
  local w="$1" out n
  mktree "$w" 3 || return 1
  mkseed "$w/base.tsv" fx1 1000 15 12 3 || return 1
  hrow "$DRIVE_HIST" 4 fx1 1000; hrow "$DRIVE_HIST" 4 fx1 1000; hrow "$DRIVE_HIST" 4 fx1 1000
  printf 'fx1 90\nfx2 1\nfx3 1\n' > "$w/d4.tsv" || return 1
  cp "$w/d4.tsv" "$w/d4.tsv.rec" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/d4.tsv" --jobs 4; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'lower the baseline' <<<"$out" || return 1
  n="$(grep -cF "Re-baseline pool 4 by dropping its rows: awk -F'\\t' -v w=4 '\$1 != w'" <<<"$out")" || n=0
  [ "$n" -eq 1 ] || return 1
  printf 'fx1 90\nfx2 1\nfx3 1\n' > "$w/d12.tsv" || return 1
  cp "$w/d12.tsv" "$w/d12.tsv.rec" || return 1
  drive --root "$w" --baseline "$w/base.tsv" --durations "$w/d12.tsv" --jobs 12 --history "$w/seedhist"; out="$OUT"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'lower the baseline' <<<"$out" || return 1
  grep -qF 'Re-baseline pool' <<<"$out" && return 1
  return 0
}

ARMS="grown equal within_band ceiling_boundary ceil_arithmetic
probe_catches_broken_comparator
env_override baseline_flag no_measurement legacy_never_usable malformed_never_usable jobs_mismatch refusals
lower_the_row_note pole_moved probe_before_corpus cwd_invariance
coverage_partial ghost_record pole_absent no_record
orphan_block stale_second_block record_pole_skipped jobs_canonical width_exact
history_first_record history_compare tracked_seed no_measurement_writes_nothing
low_share_records fail_appends_nothing history_width_isolation history_statistic
sidecar_mismatch stale_history_ignored history_precedence history_admission nonrepo_creates_nothing
history_no_collapse sidecar_consumed drop_command_quoted notes_name_drop_command
load_excludes_pole count_out_of_band count_in_band seed_pole_absent_records
producer_sequential uniform_slowdown launder_novel_count keyed_skip_launder regime_ceiling
grown_into_pole grown_keyed_absent nonpole_admission rows_per_unit append_site_pinned"

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
    DRIVE_HIST="$w/hist"
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
    env_override)        msg="AI_DLC_POLE_BASELINE is read, against a DECOY at the default path that names a different figure" ;;
    baseline_flag)       msg="--baseline is read, against the same decoy" ;;
    no_measurement)      msg="a durations file that is absent, and one that is EMPTY, each SKIP at exit 0" ;;
    legacy_never_usable) msg="(C) three huge legacy 5-column rows are never usable on a full-share run (CALIBRATING, records, no first-pole line), and three small ones do not count toward admission" ;;
    malformed_never_usable) msg="(C) 7-column rows with a non-integer load and 6-column rows are counted malformed, never usable, and a 900s pole records" ;;
    producer_sequential) msg="(E) the validator writes its own history: three calibrating runs record, the third row makes run 4 FAIL GROWN, a keyed 180s run calibrates and records, a keyed 400s run FAILS GROWN (regime), and run 8 still FAILS at 300" ;;
    regime_ceiling)      msg="(R1-cross) fx2 with 3 rows at count 10, a full count-40 dispatch: 1000 FAILS GROWN (regime) against its own max 100; exactly 200 passes, 201 fails; a 1.5x load shift records all 40 units and the next count-40 run compares against them" ;;
    grown_into_pole)     msg="(R1) fx2, dispatched at 100 beside the pole fx1 in three producer runs, grows to 1000 and becomes the pole: FAIL GROWN against fx2's own 100" ;;
    grown_keyed_absent)  msg="(R3) fx2's rows from runs with fx1 absent and present alike: a keyed run without fx1, fx2 at 900, FAILS GROWN against fx2's own 100" ;;
    nonpole_admission)   msg="non-pole fx3 (3 rows at 50) at 80 is NOT appended and the summary line counts it; at 45 it is appended" ;;
    rows_per_unit)       msg="one run appends exactly one row per on-disk dispatched unit (none for a ghost name), columns 4-7 identical across the run" ;;
    append_site_pinned)  msg="the history is written by exactly one printf of \$ROWS appended to \$HIST (awk-direct appends tore lines under concurrency)" ;;
    launder_novel_count) msg="(shape 2) a regression at a novel dispatch count FAILS GROWN (regime); under 2x it records, and the next in-band run at 700 FAILS against fx1's own rows" ;;
    keyed_skip_launder)  msg="(shape 3) a keyed run skipping fx1 FAILS on fx2 600 against fx2's own 100 (recorded beside fx1), and the next run's fx1 210 FAILS against fx1's own 150" ;;
    count_out_of_band)   msg="(A) rows at 1500s from a 20-unit dispatch against a 3-unit run at 2000s are out of band: no usable row, no GROWN" ;;
    uniform_slowdown)    msg="(shape 1) every unit 40% slower keeps the same dispatched count, so the rows stay usable and fx1 210 FAILS GROWN against 150" ;;
    low_share_records)   msg="(g) a keyed run at a 67.85% share of the record CALIBRATES and RECORDS a seven-column row (dispatched 2), where it used to SKIP on coverage" ;;
    load_excludes_pole)  msg="(a) on rows the validator wrote (load 95, the pole excluded by name), fx2 grown to 1000s FAILS GROWN against its own 100" ;;
    count_in_band)       msg="(A) rows from dispatches of 3/4/5 against a 4-unit run are all usable (inclusive edges): a 1000s pole FAILS GROWN, a 120s pole is compared and passes" ;;
    seed_pole_absent_records) msg="(f) a tracked seed naming fx1 is not consulted for a run whose pole is fx2: it CALIBRATES for fx2, prints nothing about the seed, and records" ;;
    jobs_mismatch)       msg="one seed row per pool width: --jobs 16 compares against the SECOND block, --jobs 12 against the first, and a width with no row and no history CALIBRATES at exit 0 (no SKIP)" ;;
    history_first_record) msg="A1: the first run at an uncalibrated width prints RECORDED and appends exactly one row in the producer's 7-field format" ;;
    history_compare)     msg="A2/A3: width-4 history 100x3 is READ: 1000 fails naming GROWN, the history file and the drop command; 120 passes against B=100, ceiling 133" ;;
    tracked_seed)        msg="A4/B1: width 12 with a tracked row and no history CALIBRATES against the seed: within band the pre-BL-465 line byte-for-byte, above its ceiling ABOVE SEED at exit 0, and both record" ;;
    no_measurement_writes_nothing) msg="A5: an empty durations file with a matching sidecar SKIPs and writes no history row, while a real measurement at that width does" ;;
    fail_appends_nothing) msg="A7: a FAIL against width-4 history leaves the history at three rows, while a passing run says recorded" ;;
    history_width_isolation) msg="A8: width 4 reads only width-4 rows: newer width-8 rows at 1000 do not acquit a 300s pole against B=100" ;;
    history_statistic)   msg="A9: B is the max of every usable row (300,100,200,150 -> 300): 290 passes at ceiling 399, which last-row and a 3-row window each get wrong" ;;
    history_no_collapse) msg="the ratchet does not collapse: calibrated 500/520/510 then admitted 300x3, an ordinary 450 passes against B=520 (a 3-row window would fail it at 399)" ;;
    sidecar_consumed)    msg="one published measurement is one row: four invocations over one durations file and sidecar append exactly one history row" ;;
    notes_name_drop_command) msg="D1: under history the lower-the-baseline NOTE prints the drop command for the width; from a seed it does not" ;;
    drop_command_quoted) msg="the FAIL text's drop command, printed for a history path containing a quote, runs as printed and drops only that width's rows" ;;
    sidecar_mismatch)    msg="A10: a width sidecar reading 12 (or absent) at --jobs 4 records nothing and names the sidecar, while a sidecar reading 4 records" ;;
    stale_history_ignored) msg="A11: history rows naming a pole directory that no longer exists are ignored with a NOTE, not refused, and do not enter B" ;;
    history_precedence)  msg="A12: at widths 12 and 16, three history rows outrank the tracked row in both directions (200 passes at 12, 1000 fails at 16)" ;;
    history_admission)   msg="admission: a pole inside the band but above B passes and is NOT recorded; one at or below B is appended as a fourth row" ;;
    nonrepo_creates_nothing) msg="no --history on a root that is not a repository creates nothing and says so, while the same root after git init records by default" ;;
    refusals)            msg="a row with no block of its own, two rows for one width, a missing band, a missing jobs, a pole naming no fixture directory, a zero-second row, a band over 1000%, and an empty --jobs each exit 2 and name the cause" ;;
    orphan_block)        msg="a block left without its row MID-FILE (two whole blocks, an orphan between rows, a repeated jobs line) exits 2 naming the repeat" ;;
    stale_second_block)  msg="a stale pole in the SECOND, unselected block exits 2 naming it, while the same file with a real directory there is compared" ;;
    record_pole_skipped) msg="a skipped unit costing more than the ceiling in the RECORD does not become the observed pole: this run's max (fx100 830s) is compared and passes" ;;
    jobs_canonical)      msg="'# jobs: 012' is width 12: beside a '# jobs: 12' block it is a duplicate (exit 2), alone it is selected by --jobs 12, and a CRLF baseline parses as its LF twin" ;;
    width_exact)         msg="width selection is exact: --jobs 2 against rows at 12 and 16 CALIBRATES rather than comparing against either, while --jobs 12 selects row 12" ;;
    coverage_partial)    msg="a realistic 220-of-227 dispatch is COMPARED at coverage 99.87%: a grown pole FAILS and the within-band near-miss passes" ;;
    ghost_record)        msg="a 100000s ghost row for a deleted fixture leaves a full dispatch at 100% and compared (FAIL), while the same cost on an undispatched fixture on disk is counted in the 113224s denominator" ;;
    pole_absent)         msg="(iii) one unit's history does not affect another's verdict: fx1 300 FAILS against its own 100 beside fx2 rows at 500, fx2 600 passes against its own 500, and fx3 with no rows CALIBRATES and records (admission is per unit)" ;;
    no_record)           msg="an absent and an empty cumulative record each SKIP by name, while the present record is compared and FAILS" ;;
    lower_the_row_note)  msg="a figure under half the baseline exits 0 WITH the lower-the-row NOTE, and one just over half gets no note (there is no downward FAIL)" ;;
    pole_moved)          msg="(i) an unchanged heavy unit (fx12 1132s) newly dispatched at the same count does NOT fail against the old pole: it CALIBRATES for fx12 and records" ;;
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
    probe-then-exit-0)          printf '%s' "equal within_band ceiling_boundary ceil_arithmetic env_override baseline_flag no_measurement legacy_never_usable malformed_never_usable jobs_mismatch refusals lower_the_row_note pole_moved probe_before_corpus cwd_invariance coverage_partial ghost_record pole_absent no_record orphan_block stale_second_block record_pole_skipped jobs_canonical width_exact history_first_record history_compare tracked_seed no_measurement_writes_nothing low_share_records fail_appends_nothing history_width_isolation history_statistic sidecar_mismatch stale_history_ignored history_precedence history_admission nonrepo_creates_nothing history_no_collapse sidecar_consumed drop_command_quoted notes_name_drop_command load_excludes_pole count_out_of_band count_in_band seed_pole_absent_records producer_sequential uniform_slowdown launder_novel_count keyed_skip_launder pole_moved regime_ceiling grown_into_pole grown_keyed_absent nonpole_admission rows_per_unit" ;;
    # notes_name_drop_command drives the lower-the-baseline NOTE (under history and from a seed) and
    # asserts exit 0 on both, so a downward FAIL moves it too. lower_the_row_note owns the direction;
    # the D1 arm owns what the NOTE says, and stands down for it.
    downward-note-becomes-fail) printf '%s' "cwd_invariance notes_name_drop_command" ;;
    # HISTORY NOT READ removes the ONLY source that can FAIL a push: since the seed ruling a tracked
    # row never blocks, so every arm that asserts an exit 1 reads its enforced baseline from history
    # (mkbase writes it beside the row) and each then calibrates where it asserted GROWN. That is the
    # probe-then-exit-0 shape -- the enforcement deleted, every enforcing arm moving -- and true for
    # each. history_compare owns the read; the rest own what is done with it, and each has its own
    # mutant that leaves the read in place.
    history-never-read)         printf '%s' "grown equal within_band ceiling_boundary ceil_arithmetic coverage_partial ghost_record pole_absent no_record lower_the_row_note pole_moved record_pole_skipped no_measurement fail_appends_nothing history_width_isolation history_statistic stale_history_ignored history_precedence history_admission history_no_collapse drop_command_quoted notes_name_drop_command load_excludes_pole count_in_band producer_sequential uniform_slowdown launder_novel_count keyed_skip_launder legacy_never_usable malformed_never_usable count_out_of_band regime_ceiling grown_into_pole grown_keyed_absent" ;;
    # THE ROW-COUNT EQUALITY SKIPS EVERY KEYED RUN, which is the defect it stands for: each arm below
    # drives a run timing fewer rows than the tree has directories and reads what the subject does
    # with it. coverage_partial owns the 220-of-227 case; the rest see the same skip from their own
    # keyed seed and stand down.
    row-count-equality-restored) printf '%s' "pole_absent low_share_records stale_history_ignored seed_pole_absent_records producer_sequential uniform_slowdown launder_novel_count keyed_skip_launder pole_moved regime_ceiling" ;;
    # COMPARING A WIDTH WITH NO ROW AGAINST THE WIDTH-12 ROW and the first-row selector are the
    # same wrong answer at width 4 against a width-12-only baseline: no CALIBRATING, a comparison.
    # history_first_record owns the width-with-no-row case; jobs_mismatch owns selection among rows.
    compares-against-width-12)  printf '%s' "jobs_mismatch width_exact" ;;
    # THE OLD SKIP KEPT is also what width_exact's --jobs 1 world sees: a width with no row. Both
    # findings are true; history_first_record owns "a new width calibrates and records", and
    # width_exact keeps its calibration conjunct because the regex selector is otherwise invisible.
    # history_no_collapse and sidecar_consumed both begin by calibrating a width with no row, so a
    # SKIP there records nothing and both read the absence. True of the same defect; they own the
    # window and the consume, and stand down for it.
    no-row-still-skips)         printf '%s' "width_exact history_no_collapse sidecar_consumed load_excludes_pole producer_sequential uniform_slowdown launder_novel_count keyed_skip_launder pole_moved pole_absent seed_pole_absent_records regime_ceiling" ;;
    # DIVIDING WITHOUT THE OBSERVED POLE puts the pole on one side of the ratio only, so the
    # ghost arm's printed denominator loses the pole's 1000s and no longer reads 113224. That is
    # a TRUE finding about the same defect; coverage_partial owns it because it is the arm whose
    # figure moves while every verdict in it stays the same.
    divisor-is-observed-pole)   printf '%s' "ghost_record" ;;
    # A FIRST-ROW SELECTOR IS ALSO AN INEXACT ONE: `--jobs 1` against rows at 12 and 16 selects
    # row 12 under it, exactly as a regex selector does. Both findings are true; jobs_mismatch
    # owns the first-row reader (it is the only arm whose SECOND block must be the one compared)
    # and width_exact stands down for it, owning the regex mutant alone.
    width-selects-first-row)    printf '%s' "width_exact history_first_record" ;;
    # THE LAST ROW is also a window of one: the collapse sequence ends on three admitted 300s, so
    # it reads B=300 there exactly as the K-window does. history_statistic owns the last-row reader;
    # history_no_collapse owns the window, and stands down here.
    history-last-row)           printf '%s' "history_no_collapse" ;;
    # A TRUNCATING WRITE leaves one row however many runs record, so the collapse sequence never
    # reaches K rows and calibrates where it asserted a comparison. The collapse is only expressible
    # over an ACCUMULATED history; history_admission owns accumulation, and the window arm stands down.
    history-truncating-write)   printf '%s' "history_no_collapse load_excludes_pole producer_sequential uniform_slowdown launder_novel_count keyed_skip_launder regime_ceiling" ;;
    # WITH NO SIDECAR CHECK, a consumed (emptied) sidecar no longer stops a second record: consuming
    # only has an effect THROUGH the check. sidecar_mismatch owns the check; sidecar_consumed owns the
    # consume line, and stands down here.
    sidecar-not-checked)        printf '%s' "sidecar_consumed" ;;
    # THE PRODUCER ARMS (BL-465 rework) drive the validator's own writer over consecutive runs: each
    # begins by calibrating a width with no row and accumulating history, and each keyed or shifted run
    # times fewer rows than its tree holds. So a mutant that stops a width with no row from recording,
    # truncates the history, or skips a keyed dispatch moves them too -- true of the same defect, owned
    # by the arm built for it (history_first_record, history_admission, coverage_partial).
    calibrating-without-admission) printf '%s' "producer_sequential keyed_skip_launder regime_ceiling" ;;
    drop-count-band)            printf '%s' "producer_sequential launder_novel_count regime_ceiling" ;;
    records-on-fail)            printf '%s' "producer_sequential" ;;
    # KEYED ON LOAD, any arm whose run's load differs from its rows' by more than 25% loses its rows:
    # pole_moved and notes_name_drop_command run beside a different load than their seeded rows carry,
    # and load_excludes_pole's grown unit moves the run's load by design (adversary B1). uniform_slowdown
    # owns the predicate; the rest see its consequence.
    key-on-load-not-count)      printf '%s' "pole_moved notes_name_drop_command load_excludes_pole" ;;
    # PER-UNIT (round 3). width-wide-b-restored and admission-per-width are the two halves of one wrong
    # model -- every unit's rows read as one population -- and each arm built on a second unit's rows sees
    # both: pole_moved (a heavy unit newly the pole), pole_absent (one unit's rows beside another's) and
    # keyed_skip_launder (a run recording under a different unit). pole_moved owns the comparison,
    # pole_absent owns admission; the others stand down for the half they do not own.
    width-wide-b-restored)      printf '%s' "pole_absent keyed_skip_launder" ;;
    admission-per-width)        printf '%s' "pole_moved keyed_skip_launder" ;;
    # THE OBSERVED POLE READ FROM THE RECORD makes the ghost's 100000s the pole in ghost_record's world,
    # which then calibrates where the arm asserts GROWN. True of the same defect; record_pole_skipped owns it.
    observed-pole-from-record)  printf '%s' "ghost_record" ;;
    *) printf '' ;;
  esac
}

mut() { # <label> <anchor-fixed-string> <sed-expr> <arm-that-must-fail> [count] [injected-marker]
  local label="$1" anchor="$2" expr="$3" want="$4" n_want="${5:-1}" marker="${6:-}"
  local dir="$MUTROOT/$label" copy n_anchor n_after n_mark
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
  # QUEUED, NOT RUN HERE. Every guard above is synchronous and reports in place; the arms-against-
  # a-mutant run is the expensive part, and it goes to the bounded pool below (mut_pool), which
  # writes each mutant's verdict list to its own file. mut_score then reads them in queue order.
  printf '%s\t%s\n' "$label" "$want" >> "$MUTROOT/.queue"
}

# THE MUTANT POOL, AT MOST MUT_JOBS WIDE. Each queued mutant runs the FULL arm list against its copy
# in a background subshell, writing `<name>:<0|1>` lines to `$MUTROOT/<label>.res`. Bash 3.2 has no
# `wait -n`, so the pool runs in WAVES of MUT_JOBS and waits on each wave's pids by number -- never
# on a process-table grep. Every arm still runs against every mutant; only the scheduling changed.
# The width is capped at 4 because this fixture itself runs inside the pre-push pool.
MUT_JOBS=4
mut_pool() {
  local label want pids="" n=0 p
  while IFS="$(printf '\t')" read -r label want; do
    [ -n "$label" ] || continue
    ( run_arms "$MUTROOT/$label/$SUBJ_BASE" > "$MUTROOT/$label.res" 2>/dev/null ) &
    pids="$pids $!"; n=$((n + 1))
    if [ "$n" -ge "$MUT_JOBS" ]; then
      for p in $pids; do wait "$p"; done
      pids=""; n=0
    fi
  done < "$MUTROOT/.queue"
  for p in $pids; do wait "$p"; done
}

# SCORING, in queue order, from the per-mutant files. A missing or short file is a mutant whose
# arms did not all report, which is FIXTURE BROKEN territory and scored as a failure by name rather
# than read as a survival or a kill.
mut_score() {
  local label want out rc others allowed unexpected o n_got
  while IFS="$(printf '\t')" read -r label want; do
    [ -n "$label" ] || continue
    out="$(cat "$MUTROOT/$label.res" 2>/dev/null)"
    n_got="$(printf '%s\n' "$out" | grep -c ':')" || n_got=0
    if [ "$n_got" -ne "$ARM_COUNT" ]; then
      bad "MUTANT $label: $n_got of $ARM_COUNT arms reported a verdict in the pool -- a mutant scored on a partial arm list is neither a kill nor a survival"
      continue
    fi
    mut_judge "$label" "$want" "$out"
  done < "$MUTROOT/.queue"
}

mut_judge() { # <label> <want> <run_arms output>
  local label="$1" want="$2" out="$3" rc others allowed unexpected o
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
  'lower the baseline' \
  '/lower the baseline/a\
  exit 1 # MUTANT-DOWNWARD-FAIL' \
  lower_the_row_note \
  1 \
  'MUTANT-DOWNWARD-FAIL'

# M7 (C): LEGACY ROWS USABLE -- a 5-column row, which carries no count, read as comparable to anything.
# Three huge legacy rows then become B and the full-share run is compared against them.
mut legacy-usable \
  'if (NF == 5) { legacy++; next }' \
  's/if (NF == 5) { legacy++; next }/if (NF == 5) { print $2, $3 + 0, $4, "-"; next }/' \
  legacy_never_usable

# M8 (C): A MALFORMED ROW USABLE -- the well-formedness test on the load and count columns dropped.
mut malformed-usable \
  'if (!wf) { malformed++; next }' \
  's/if (!wf) { malformed++; next }/if (0) { malformed++; next }/' \
  malformed_never_usable

# M9: THE ROW-COUNT EQUALITY RESTORED -- the defect this predicate replaced. Injected after the
# coverage line, so a 220-of-227 dispatch is skipped again although its coverage is 99.87%.
mut row-count-equality-restored \
  '"$COV_TXT" "$NUM" "$DEN" "$fx_count"' \
  '/"\$COV_TXT" "\$NUM" "\$DEN" "\$fx_count"$/a\
[ "$(awk '"'"'NF == 2 { n++ } END { print n + 0 }'"'"' "$DUR")" -eq "$fx_count" ] || { printf "   SKIP -- partial dispatch\\n"; exit 0; } # MUTANT-ROW-EQUALITY' \
  coverage_partial \
  1 \
  'MUTANT-ROW-EQUALITY'

# M10: THE ON-DISK JOIN DROPPED, so a ghost key the hook's merge never prunes counts as work
# this run failed to do and a full dispatch reads as 12% covered.
mut on-disk-join-dropped \
  '&& ($1 in d) { s += $2;' \
  's/ && (\$1 in d) { s += \$2;/ { s += $2;/' \
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

# M12 (4): THE SEED CONSULTED FOR ANY UNIT -- the tracked row compared against whatever unit is the pole,
# the cross-unit comparison the per-unit design forbids. Only the arm whose pole is not the seed's unit
# can see it.
mut seed-consulted-for-other-unit \
  'elif [ -n "$BL" ] && [ "$(printf' \
  's/^elif \[ -n "\$BL" \] && \[ "\$(printf .*$/elif [ -n "$BL" ]; then # MUTANT-ANY-SEED/' \
  seed_pole_absent_records \
  1 \
  'MUTANT-ANY-SEED'

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

# ---------------------------------------------------------------------------------------
# THE HISTORY MUTANTS (BL-465), each named for the wrong implementation it stands for.
# ---------------------------------------------------------------------------------------

# H1: HISTORY NEVER READ -- the rows are written and nothing consults them, so every width without a
# tracked row calibrates forever. The read itself is emptied; the writer is untouched.
mut history-never-read \
  'H_RAW="$(printf' \
  's/^  H_RAW="\$(printf.*$/  H_RAW="" # MUTANT-NO-READ/' \
  history_compare \
  1 \
  'MUTANT-NO-READ'

# H2: WRITES, BUT COMPARES AGAINST THE WIDTH-12 ROW -- the tracked row selected for every width.
mut compares-against-width-12 \
  'BL="$(select_width "$BL_ALL" "$JOBS")"' \
  's/^BL="\$(select_width "\$BL_ALL" "\$JOBS")"$/BL="$(select_width "$BL_ALL" 12)"/' \
  history_first_record

# H3a (g): THE COVERAGE SKIP RESTORED -- a run below COV_MIN% of the record exits before the history
# is read, so no keyed push ever records and the width never forms history: the defect BL-465 is.
# (Its predecessor here, "records at a coverage SKIP", lost its subject when the SKIP was removed.)
mut coverage-skip-restored \
  '"$COV_TXT" "$NUM" "$DEN" "$fx_count"' \
  '/"\$COV_TXT" "\$NUM" "\$DEN" "\$fx_count"$/a\
[ "$((NUM * 100))" -ge "$((DEN * 90))" ] || { printf "   SKIP -- coverage below 90%%\\n"; exit 0; } # MUTANT-COVSKIP' \
  low_share_records \
  1 \
  'MUTANT-COVSKIP'

# H3b: A FAIL STILL APPENDS UNIT ROWS -- a grown pole, and every unit beside it, enter the history the
# run was just judged against. Injected after the FAIL text, before its exit.
mut records-on-fail \
  'covers the run-to-run spread this figure was calibrated against' \
  '/covers the run-to-run spread this figure was calibrated against/a\
  record_run # MUTANT-REC-FAIL' \
  fail_appends_nothing \
  1 \
  'MUTANT-REC-FAIL'

# H4: THE SKIP KEPT -- a width with no tracked row and too little history SKIPs as before BL-465.
mut no-row-still-skips \
  '  SRC=calibrating' \
  's/^  SRC=calibrating$/  printf "   SKIP -- pool width %s has no baseline row\\n" "$JOBS"; exit 0/' \
  history_first_record

# H5: NO WIDTH FILTER on the history read -- every width's rows pooled into one statistic.
mut history-no-width-filter \
  'NF >= 5 && $1 == j && $3 ~' \
  's/NF >= 5 \&\& \$1 == j \&\& \$3 ~/NF >= 5 \&\& $3 ~/' \
  history_width_isolation

# H6: THE LAST ROW AND NOT THE MAX of every usable row.
mut history-last-row \
  'if [ "$_hs" -gt "$H_B" ]; then H_B="$_hs"; H_BPOLE="$_hp"; H_BFIXT="$_hf"; H_BCOUNT="$_hl"; fi' \
  's/if \[ "\$_hs" -gt "\$H_B" \]; then H_B="\$_hs"; H_BPOLE="\$_hp"; H_BFIXT="\$_hf"; H_BCOUNT="\$_hl"; fi/H_B="$_hs"; H_BPOLE="$_hp"; H_BFIXT="$_hf"; H_BCOUNT="$_hl"/' \
  history_statistic

# H11: THE K-WINDOW RESTORED -- B over the 3 most recent rows, the ratchet that collapses. Injected
# as the line the tip had before the fix, at the head of the max loop; the counter it needs rides on
# the same line so the mutation is one site.
mut k-window-restored \
  'if [ "$_hs" -gt "$H_B" ]; then H_B="$_hs"; H_BPOLE="$_hp"; H_BFIXT="$_hf"; H_BCOUNT="$_hl"; fi' \
  's/^  if \[ "\$_hs" -gt "\$H_B" \]; then H_B=/  _hi=$((${_hi:-0} + 1)); [ "$_hi" -gt "$((H_N - HIST_K))" ] || continue # MUTANT-K-WINDOW\
  if [ "$_hs" -gt "$H_B" ]; then H_B=/' \
  history_no_collapse \
  1 \
  'MUTANT-K-WINDOW'

# H12: THE SIDECAR NOT CONSUMED -- one published measurement recorded once per invocation.
mut sidecar-not-consumed \
  ': > "$side" 2>/dev/null' \
  's/^    : > "\$side" 2>\/dev\/null$/    : # MUTANT-NO-CONSUME/' \
  sidecar_consumed \
  1 \
  'MUTANT-NO-CONSUME'

# H13: THE SEED ENFORCED -- a tracked row FAILs at a width still calibrating, as it did before.
mut seed-enforced \
  '  if [ "$SRC" = seed ]; then' \
  's/^  if \[ "\$SRC" = seed \]; then$/  if false; then/' \
  tracked_seed

# H14: THE DROP COMMAND HAND-QUOTED -- `'%s'` around the path, which a quote in the path splits.
# Two sites -- the FAIL text and the NOTEs' drop_hint -- because a hand-quoted path is wrong in both,
# and a mutation of one leaves the other quoting correctly. drop_command_quoted runs the FAIL's copy.
mut drop-command-hand-quoted \
  '%q > %q && mv %q %q' \
  "s/%q > %q \\&\\& mv %q %q/'%s' > '%s' \\&\\& mv '%s' '%s'/" \
  drop_command_quoted \
  4

# H7: ADMITS ABOVE B -- every passing run appended, so B creeps up a band at a time.
mut admits-above-b \
  'if [ "$SRC" = history ] && [ "$OBS_SECS" -gt "$BL_SECS" ]; then' \
  's/if \[ "\$SRC" = history \] && \[ "\$OBS_SECS" -gt "\$BL_SECS" \]; then/if false; then/' \
  history_admission

# H8: A TRUNCATING WRITE -- each record replaces the file, so history never holds more than one row.
mut history-truncating-write \
  '>> "$HIST" 2>/dev/null' \
  's/>> "\$HIST" 2>\/dev\/null/> "$HIST" 2>\/dev\/null/' \
  history_admission

# H9: STALE HISTORY ROWS COUNTED -- a sharded-away pole's rows enter B.
mut stale-history-counted \
  'if (!($2 in d)) { gone++; next }' \
  's/if (!(\$2 in d)) { gone++; next }/if (0) { gone++; next }/' \
  stale_history_ignored

# L1 (A): THE COUNT BAND DROPPED -- every 7-column row usable whatever dispatch it was taken beside, so
# a figure recorded beside a quarter of the units is compared against one taken beside all of them.
# Both edges are one predicate's two sites, so the set is emptied together.
mut drop-count-band \
  '{ outband++; next }' \
  '/{ outband++; next }/d' \
  count_out_of_band \
  2

# L1b (A): KEYED ON LOAD, NOT COUNT -- the shipped predicate before the adversary's blocker. A uniform
# slowdown moves the load out of band and the regression calibrates instead of failing.
# The band reads the load column against this run's load: three sites in one sed, keyed on the awk
# variable binding, whose anchor must go to zero.
mut key-on-load-not-count \
  '-v C="$DISP"' \
  's/-v C="\$DISP"/-v C="$LOAD"/; s/if (\$7 \* 100 < C/if ($6 * 100 < C/; s/if (\$7 \* 100 > C/if ($6 * 100 > C/' \
  uniform_slowdown

# L6 (a): RECORD THE POLE ONLY -- the pre-option-(a) recorder. Every non-pole unit is skipped, so a unit
# that grows into the pole has no rows of its own and calibrates at its grown figure.
mut record-pole-only \
  'if (u in seen) next' \
  's/if (u in seen) next/if (u in seen || u != p) next/' \
  grown_into_pole

# L8 (2): NON-POLE UNITS BYPASS ADMISSION -- every unit but the pole appended whatever it cost, so a
# non-pole regression raises that unit's B before it ever becomes the pole.
mut nonpole-bypass-admission \
  'ok = (lim < 0 || s <= lim)' \
  's/ok = (lim < 0 || s <= lim)/ok = (u != p || lim < 0 || s <= lim)/' \
  nonpole_admission

# L9 (1): GHOST UNITS RECORDED -- a durations row naming no fixture directory written to history.
mut ghost-units-recorded \
  'if (!(u in d)) next' \
  's/if (!(u in d)) next/if (0) next/' \
  rows_per_unit

# L10 (8): ROWS WRITTEN BY awk DIRECTLY -- awk appends to the history itself and the shell printf
# writes nothing. Behaviourally identical with one writer; it tore 2-112 lines with two. Only the
# structural arm can see it.
mut rows-written-by-awk \
  'buf = buf sprintf(' \
  's/buf = buf sprintf(\(.*\))$/printf(\1) >> hf/' \
  append_site_pinned

# L2 (a): THE OBSERVED POLE COUNTED IN THE LOAD -- the grown unit votes on its own comparability, so
# the more it grows the less comparable the history becomes, and a large enough regression calibrates
# instead of failing (adversary B1).
mut include-obs-in-load \
  'if ($1 != p) l += $2' \
  's/if (\$1 != p) l += \$2/l += $2/' \
  load_excludes_pole

# L3 (A): THE BAND EXCLUSIVE AT ITS LOWER EDGE -- a row at exactly 75% of the count dropped.
mut band-edge-exclusive \
  'if ($7 * 100 < C * (100 - band))' \
  's/if (\$7 \* 100 < C \* (100 - band))/if ($7 * 100 <= C * (100 - band))/' \
  count_in_band

# L4 (1): WIDTH-WIDE B RESTORED -- rows naming other units consulted, so a unit is compared against
# another unit's figure. An unchanged heavy unit newly dispatched then FAILS against the old pole's B.
mut width-wide-b-restored \
  'if ($2 != p) { other++; next }' \
  's/if (\$2 != p) { other++; next }/if (0) { other++; next }/' \
  pole_moved

# L5 (7): THE REGIME CEILING DROPPED -- a unit with K rows and none comparable is never judged, so a
# regression that moved itself to a new dispatch count passes and calibrates. The FROZEN state was this
# acquittal with a different label.
mut regime-ceiling-dropped \
  'if [ "$OBS_SECS" -gt "$RCEIL" ]; then' \
  's/if \[ "\$OBS_SECS" -gt "\$RCEIL" \]; then/if false; then/' \
  regime_ceiling

# L7 (3): ADMISSION PER WIDTH -- every unit's rows count toward the frozen test, so a unit with no rows
# of its own is frozen at another unit's max and its first sightings are never recorded.
mut admission-per-width \
  'if (wf && $2 == p) { arows++;' \
  's/if (wf \&\& \$2 == p) { arows++;/if (wf) { arows++;/' \
  pole_absent

# H10: THE WIDTH SIDECAR NOT CHECKED -- a durations file another pool published is recorded here.
mut sidecar-not-checked \
  'if [ "$sj" != "$JOBS" ]; then' \
  's/if \[ "\$sj" != "\$JOBS" \]; then/if false; then/' \
  sidecar_mismatch

# H15 (D2): HISTORY DOES NOT OUTRANK THE SEED -- history is the source only at a width with no
# tracked row. The mkbase arms keep their tracked block at width 16 and drive other widths, so they
# read history alone and cannot see this; history_precedence, with a seed AT both driven widths, can.
mut history-prefers-seed \
  'if [ "$H_N" -ge "$HIST_K" ]; then' \
  's/^if \[ "\$H_N" -ge "\$HIST_K" \]; then$/if [ -z "$BL" ] \&\& [ "$H_N" -ge "$HIST_K" ]; then/' \
  history_precedence

# H16 (D1): THE NOTES' DROP COMMAND REMOVED -- the operator under history told to edit a row that is
# not read. Both call sites, keyed on the predicate they share.
mut notes-drop-hint-removed \
  '[ "$SRC" = history ] && drop_hint' \
  's/\[ "\$SRC" = history \] \&\& drop_hint/: # MUTANT-NO-HINT/' \
  notes_name_drop_command \
  1

# THE MUTANT POOL RUNS HERE, after EVERY `mut` above has built, guarded and queued its copy, and
# before the control. A `mut` placed below this line would be queued after the pool drained and
# never scored -- the assertion-count check at the end is what reports that, as it did once.
mut_pool
mut_score

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
# readset_pid_start is NOT extracted: every lock seeded here is a two-field lock, which the reader
# judges at its legacy branch before it reads a start time, so nothing here runs `ps`. That is
# deliberate -- /bin/ps is setuid, the read-set deriver's sandbox refuses it, and a fixture that runs
# it can never be traced. The start-time worlds (BL-463) live in readset-skip, which runs them on
# every ordinary run and SKIPs them, by name, only when it detects it is inside that sandbox.
{ awk '/^readset_lock_stale\(\) \{/,/^}/' "$PG_HOOK"
  awk '/^pole_guard_step\(\) \{/,/^}/' "$PG_HOOK"
  printf 'overlap_probe() {\n'
  awk '/^  READSET_TRACE_OVERLAP=0$/ { p = 1 } p { print } p && /^  fi$/ { exit }' "$PG_HOOK"
  printf '}\n'
} > "$PG_LIB"
[ "$(grep -c '^[a-z_]*() {' "$PG_LIB")" -eq 3 ] && grep -q 'readset_lock_stale' "$PG_LIB" && grep -q 'READSET_TRACE_OVERLAP=1' "$PG_LIB" \
  || broken "could not extract readset_lock_stale, pole_guard_step and the overlap probe from $PG_HOOK"
# The stub's exit is PG_RC (default 0), so the key-record arms below can make the pole FAIL.
printf '#!/bin/bash\nprintf "%%s\\n" "$*" > "$PG_ARGS"\nexit "${PG_RC:-0}"\n' > "$PGW/scripts/validate-suite-pole.sh"
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
# A POLE FAIL FORGETS THE CONTENT KEY (D3). fixture_suite_step records the key before the pole step
# runs, so without this a push red on the pole alone is skipped on its re-push and the guard reads
# /dev/null. Driven through the SAME extracted pole_guard_step, stub validator exiting PG_RC, with a
# real key-record file: exit 1 must remove it and return 1; exit 0 must keep it and return 0.
# kr_drive <lib> <validator-rc> -> "<step rc>|<key record: kept|gone>"
kr_drive() {
  local lib="$1" vrc="$2" o="$PGW/k.$RANDOM"
  mkdir -p "$o"; printf 'somekey 9 2026-01-01T00:00:00Z\n' > "$o/key"
  ( cd "$PGW" || exit 1
    . "$lib"
    READSET_LOCAL="$PGW/rl-none"; FIXTURE_JOBS=12; LASTRUN_RECORD=last.tsv; DURATIONS_RECORD=dur.tsv
    SUITE_SKIPPED=0; READSET_TRACE_OVERLAP=0; KEY_RECORD="$o/key"
    export PG_ARGS="$o/args" PG_RC="$vrc"
    pole_guard_step > "$o/step" 2>&1; printf '%s' "$?" > "$o/rc"
  )
  printf '%s|%s' "$(cat "$o/rc" 2>/dev/null)" "$([ -e "$o/key" ] && echo kept || echo gone)"
}
pg_arm keyfail "$(kr_drive "$PG_LIB" 1)" "1|gone" \
  "hook pole step: a pole FAIL returns 1 AND removes the content-key record, so the re-push re-runs the suite instead of skipping to /dev/null"
pg_arm keypass "$(kr_drive "$PG_LIB" 0)" "0|kept" \
  "hook pole step: a pole PASS returns 0 and keeps the content-key record"
kr_mut() { # <name> <from> <to> <validator-rc> <correct result>
  local m="$PGW/krm.$1.sh" n r
  n="$(grep -cF -- "$2" "$PG_LIB")" || n=0
  HOOK_ARMS=$((HOOK_ARMS + 1))
  if [ "$n" != 1 ]; then bad "hook-key MUTANT $1: anchor matched $n time(s), not 1 -- DID NOT APPLY"; return; fi
  MF="$2" MT="$3" awk '{ i = index($0, ENVIRON["MF"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["MT"] substr($0, i + length(ENVIRON["MF"])); print }' "$PG_LIB" > "$m"
  if cmp -s "$PG_LIB" "$m"; then bad "hook-key MUTANT $1: the copy is unchanged"; return; fi
  r="$(kr_drive "$m" "$4")"
  if [ "$r" = "$5" ]; then bad "hook-key MUTANT $1 SURVIVED: '$r'"; else ok "hook-key MUTANT $1 is KILLED: '$r'"; fi
}
kr_mut norm 'rm -f "$KEY_RECORD"' ':' 1 "1|gone"

# THE WIDTH SIDECAR (BL-465), extracted from fixture_suite_step the same way: from the line that
# empties `$LASTRUN_RECORD.jobs` to the `fi` closing its write, driven with a stub run_fixtures in
# three outcomes. Every world starts with a STALE sidecar reading 16 and a stale non-empty .last, so
# "emptied" and "never written" are different results. green: the pool truncates .last, publishes
# it, returns 0 -> the sidecar reads 12. red: truncates, returns 1 -> empty. no-change (the read-set
# skip): truncates and returns 0 with nothing published -> empty.
SC_LIB="$PGW/sc.sh"
{ printf 'sidecar_probe() {\n'
  awk '/^  : > "\$LASTRUN_RECORD\.jobs" 2>\/dev\/null$/ { p = 1 } p { print } p && /^  fi$/ { exit }' "$PG_HOOK"
  printf '}\n'
} > "$SC_LIB"
grep -q 'run_fixtures || return 1' "$SC_LIB" && grep -qF '"$FIXTURE_JOBS" > "$LASTRUN_RECORD.jobs"' "$SC_LIB" \
  || broken "could not extract the width-sidecar lines from fixture_suite_step in $PG_HOOK"
sc_drive() { # <lib> <outcome: green|red|nochange> -> the sidecar's content, or <empty>
  local lib="$1" oc="$2" d="$PGW/sc.$RANDOM"
  mkdir -p "$d"
  printf 'fx1 9\n' > "$d/last"; printf '16\n' > "$d/last.jobs"
  ( . "$lib"
    LASTRUN_RECORD="$d/last"; FIXTURE_JOBS=12
    run_fixtures() {
      : > "$LASTRUN_RECORD"
      case "$oc" in green) printf 'fx1 5\n' > "$LASTRUN_RECORD"; return 0 ;; red) return 1 ;; *) return 0 ;; esac
    }
    sidecar_probe ) >/dev/null 2>&1
  local v; v="$(cat "$d/last.jobs" 2>/dev/null)"
  printf '%s' "${v:-<empty>}"
}
pg_arm scgreen "$(sc_drive "$SC_LIB" green)" "12" \
  "hook sidecar: a green pool that published durations leaves .last.jobs reading the pool width"
pg_arm scred "$(sc_drive "$SC_LIB" red)" "<empty>" \
  "hook sidecar: a red pool leaves .last.jobs EMPTY, never the stale width from an earlier push"
pg_arm scnochange "$(sc_drive "$SC_LIB" nochange)" "<empty>" \
  "hook sidecar: a pool that published nothing (read-set no-change) leaves .last.jobs empty"
sc_mut() { # <name> <from> <to> <outcome> <correct result>
  local m="$PGW/scm.$1.sh" n r
  n="$(grep -cF -- "$2" "$SC_LIB")" || n=0
  HOOK_ARMS=$((HOOK_ARMS + 1))
  if [ "$n" != 1 ]; then bad "hook-sidecar MUTANT $1: anchor matched $n time(s), not 1 -- DID NOT APPLY"; return; fi
  MF="$2" MT="$3" awk '{ i = index($0, ENVIRON["MF"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["MT"] substr($0, i + length(ENVIRON["MF"])); print }' "$SC_LIB" > "$m"
  if cmp -s "$SC_LIB" "$m"; then bad "hook-sidecar MUTANT $1: the copy is unchanged"; return; fi
  r="$(sc_drive "$m" "$4")"
  if [ "$r" = "$5" ]; then bad "hook-sidecar MUTANT $1 SURVIVED: '$r'"; else ok "hook-sidecar MUTANT $1 is KILLED: '$r'"; fi
}
sc_mut notruncate ': > "$LASTRUN_RECORD.jobs"' ':' red "<empty>"
sc_mut nowrite 'printf '"'"'%s\n'"'"' "$FIXTURE_JOBS" > "$LASTRUN_RECORD.jobs"' ':' green "12"
sc_mut nopublishgate 'if [ -s "$LASTRUN_RECORD" ]; then' 'if true; then' nochange "<empty>"

# No mutant anywhere deletes the legacy branch (`[ -n "$s" ] || return 1`): one was built and moved
# readset-skip's `legacylive` world AND the `live` hook-step arm above, whose seed is also a
# two-field lock. That arm owns the regression (an upgrade turning every older lock stale) and kills
# it; `legacylive` adds only the no-announcement conjunct.

# EXPECTED_ASSERTIONS, DERIVED FROM THE ARM LIST rather than typed. A hardcoded total goes
# stale the release somebody adds an arm, and it goes stale SILENTLY in the direction that
# matters — a fixture reporting fewer assertions than it has arms reads as a complete run.
# The three addends are counted where they are produced: ARM_COUNT from $ARMS, MUT_COUNT
# incremented by every `mut` call, and the unmutated control, which is straight-line and
# cannot vary.
EXPECTED_ASSERTIONS=$((ARM_COUNT + MUT_COUNT + 1 + HOOK_ARMS))
# HOOK_WANT is derived from this file's own call lines: one assertion per pg_arm/pg_mut.
HOOK_WANT="$(grep -cE '^(pg_arm|pg_mut|sc_mut|kr_mut) ' "$HERE/run.sh")" || HOOK_WANT=0
[ "$HOOK_WANT" -ge 6 ] || broken "counted $HOOK_WANT hook-step call lines in $HERE/run.sh, expected at least 6"
[ "$HOOK_ARMS" -eq "$HOOK_WANT" ] || { printf '  FAIL  %s hook-step assertions ran, %s expected\n' "$HOOK_ARMS" "$HOOK_WANT"; fails=$((fails + 1)); }
if [ "$asserts" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf '  FAIL  %s assertions ran, %s expected — an arm did not execute\n' "$asserts" "$EXPECTED_ASSERTIONS"
  fails=$((fails + 1))
fi

printf '  %s failed, %s mutant(s) killed, %s assertions\n' "$fails" "$kills" "$asserts"
[ "$fails" -eq 0 ] || { echo "suite-pole-guard: FAIL ($fails)"; exit 1; }
echo "suite-pole-guard: PASS"
exit 0
