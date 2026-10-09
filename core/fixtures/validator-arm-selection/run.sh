#!/usr/bin/env bash
# validator-arm-selection — `--arms I<n>` must run the arm it names, and nothing may become
# unreachable because of it.
#
# WHAT THIS GUARDS. scripts/validate-enforcement-map.sh is invoked once per assertion by three
# mutation batteries, each assertion testing exactly one invariant, and a full run is ~19.5
# CPU-seconds. `--arms` slices the file to the prologue, the selected units and the verdict
# block. The saving is the largest single lever in the suite; the risk it introduces is this
# repository's named failure class, because an arm that stops running prints exactly what an
# arm that passed prints.
#
# THE THREE BATTERIES ARE HALF THE PROOF AND THEY ARE NOT REPEATED HERE. Every mutant they
# seed is a presence assertion: the validator MUST report a specific message. Convert the call
# site to `--arms <id>` and a selection that broke that arm's reachability turns the battery
# red. That half is free and it is the strongest half. What it cannot see is the other
# direction -- an arm that is selected, runs, and quietly evaluates an EMPTY subject because
# the value it reads was computed by a unit that did not run. That is what this fixture is
# for, and it was not hypothetical: measured before the hoist landed, thirteen of the
# eighty-one units read a name another unit assigned, and `i54_files` read that way inside a
# `$( )` killed only the subshell -- exit 0, no finding, an arm silently scanning nothing.
#
# WHY THE CLEAN-TREE SWEEP IS NOT VACUOUS, WHICH IS THE OBVIOUS OBJECTION. On a clean corpus
# every arm reports nothing, so comparing a selected run's FINDINGS against a full run's
# compares empty with empty ninety-four times and reads exactly like ninety-four proofs. The
# non-vacuous content of arm 4 is its STDERR predicate -- `unbound variable`, `command not
# found`, `syntax error` -- which is precisely what a broken slice emits and what a clean one
# cannot. Arm 5 is the mutant that proves that predicate can fire. Arm 6 carries the findings
# half, against a tree seeded to make several arms speak at once, and arm 7 is its mutant.
#
# IDS IN ONE UNIT ARE NOT A DEFECT AND ARE NOT TREATED AS ONE. Ten arm headers are indented
# because they sit inside an enclosing block, so they share a unit with the column-0 arm above
# them -- I31 with I12, and nine layer-contract arms with I36/I37/I38. Selecting either id
# selects that whole unit and the two runs are byte-identical by construction. The disjointness
# arm below therefore groups ids by their OWN output first and compares GROUPS, and it carries
# a floor on the group count so that a selector which stopped selecting collapses to one group
# and fails rather than satisfying disjointness vacuously.
set -u

NAME="validator-arm-selection"
DIR="$(cd "$(dirname "$0")" && pwd)"

# --- THE SHARD SPLIT, AND IT IS A MEASUREMENT RATHER THAN A PREFERENCE --------------------
# This unit became the pre-push suite's POLE the release it was added -- 220 of a 245-second
# wall. The suite's makespan tracks its single longest DIRECTORY, because `core/fixtures/*/`
# is what the outer pool globs, so an inner pool here cannot reach it.
#
# WHERE THE TIME ACTUALLY GOES, measured solo with `/usr/bin/time -p` on an otherwise idle
# box, 88.6s wall / 255 CPU-seconds, by instrumenting every block of this file:
#
#     arm 0 the plain baseline run          15s
#     arm 3 --arms <all 94 ids>             15s
#     arm 4 the 94-id clean sweep           12s
#     arm 6 the seeded tree's plain run     16s
#     arm 6 the 94-id attribution sweep     11s
#     arm 7 the neutered selector, 3 reps   18s
#     everything else (seed, mutants, ids)   2s
#
# Those are the SERIAL costs of each block. Arm 6's two units -- the seeded plain run and its
# attribution sweep -- no longer run back to back: they are dispatched concurrently and each is
# waited on its own (see arm 6). Each still costs what the table says; this file claims nothing
# about the wall clock that overlap buys, and shard 'b' is not the suite's pole.
#
# So it is FOUR near-full validator runs and two 94-id sweeps, not "the 94 ids" -- the sweeps
# are 26% of it. That rules out trimming: every one of those units is a total derivation, and
# the only way to make one cheaper is to run it over fewer ids, which turns it into a sample.
#
# THE PARTITION IS BY PREREQUISITE, NOT ROUND-ROBIN, and that is forced rather than chosen.
# Round-robin is right for enforcement-map-sites, whose assertions are independent and
# uniformly shaped. Here the phases fall into two clusters with DISJOINT prerequisites: four
# of them differential against the plain-tree baseline, six of them against a seeded tree. A
# round-robin deal would put members of both clusters in both shards and every shard would
# pay both 15-second prerequisites. Splitting on the cluster boundary means the baseline is
# computed once and the seeded tree once, so this shard costs NO extra CPU -- unlike the
# earlier families in this program, where every shard re-ran a shared control.
#
# WHAT REPLACES THE PER-SHARD CONTROL. enforcement-map-sites runs its A00 control in every
# shard because its assertions differential against one tree. Shard 'a' here IS that control
# -- arm 0's plain run licenses arms 3 and 4 and nothing else. Shard 'b' differentials against
# the SEEDED tree, and its control is the `N_SEEDED < 3` guard below: a validator that had
# stopped running produces no findings on that tree and the shard reports FIXTURE BROKEN
# rather than a clean sweep. Neither shard can report green having run nothing.
SHARDS="a b"
PHASES_a="width unknown-id grammar i66-onehook all-ids sweep"
PHASES_b="attrib union partition m1 m2 m3"

# --- THE INNER POOL WIDTH, resolved in ONE place -------------------------------------------
# Default 6 (the reasoning is beside the pools below). The read-set deriver runs this fixture
# with VAS_INNER_POOL_WIDTH=1 (BL-375): at 6 the concurrent `grep -r` sweeps outrun the sandbox
# tracer's `log stream` and it drops reports, so the trace is OMITTED. The width changes the
# SCHEDULE, not the work -- every id is still dispatched and every file still read -- so a
# read-set traced at width 1 is the read-set at width 6. No AI_DLC_ prefix, as
# future-proofing against the fixture env scrubs keyed on it; none sits on this path today.
#
# A value that is not an integer from 1 to 64 is FIXTURE BROKEN (exit 2), never a regression:
# `xargs -P 0` means UNLIMITED on BSD, and a non-number makes xargs refuse, which the sweep's own
# guard would report as a pool that did not run -- a false finding about the subject.
# THE LENGTH IS BOUNDED BEFORE ANY NUMERIC TEST. A 20-digit value overflows `test`, which then
# errors and returns FALSE, so `-lt 1` alone lets it through to an xargs that refuses it. Three
# digits cannot overflow, and 64 is the ceiling.
JOBS="${VAS_INNER_POOL_WIDTH:-6}"
case "$JOBS" in
  ''|*[!0-9]*) echo "FIXTURE BROKEN: VAS_INNER_POOL_WIDTH='$JOBS' is not an integer from 1 to 64" >&2; exit 2 ;;
esac
if [ "${#JOBS}" -gt 3 ] || [ "$JOBS" -lt 1 ] || [ "$JOBS" -gt 64 ]; then
  echo "FIXTURE BROKEN: VAS_INNER_POOL_WIDTH='$JOBS' is not an integer from 1 to 64" >&2; exit 2
fi
# The cheap re-entry mode the width arms below drive: the resolved width, and nothing else.
if [ "${1:-}" = "--print-width" ]; then
  printf '%s\n' "$JOBS"; exit 0
fi

# THE SHARD ARRIVES AS AN ARGUMENT, NOT AS AN ENVIRONMENT VARIABLE. The re-entrant worker
# modes below are dispatched by argument too, and a fixture that took its identity from the
# environment would silently fall back to shard 'a' wherever that name failed to reach it --
# the suite would then run shard 'a' twice and report two green fixtures. It is read HERE,
# ahead of the root resolution, so the SKIP line a consumer would print names the shard it
# was actually asked for rather than the base fixture.
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${PHASES_$GROUP:-}\""
# AN EMPTY SHARD PASSES EVERY ASSERTION IT NEVER MADE. A name in SHARDS with no PHASES_ list
# would run the prologue, print a clean banner and exit 0.
if [ -z "$MINE" ]; then
  echo "FIXTURE ERROR: shard '$GROUP' is declared in SHARDS but has no PHASES_$GROUP list; a shard dealt no phases passes everything it never checked" >&2
  exit 2
fi
BASENAME="$NAME"
[ "$GROUP" = a ] || NAME="$NAME-$GROUP"

want()     { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
want_any() { for _p in "$@"; do want "$_p" && return 0; done; return 1; }

# BOTH LAYOUTS NAMED, never a single walk-up (I33c). Here the fixture sits at
# core/fixtures/<name>/; the consumer layout puts it at tests/fixtures/<name>/. This unit is
# .dist-only and only ever runs here, but a resolver that names one layout is the shape the
# invariant forbids, and a fixture is not the place to make an exception to it.
ROOT=""
for cand in "$DIR/../../.." "$DIR/../.."; do
  if [ -f "$cand/scripts/validate-enforcement-map.sh" ] && [ -f "$cand/scripts/render-invariant-index.sh" ]; then
    ROOT="$(cd "$cand" && pwd)"; break
  fi
done
if [ -z "$ROOT" ]; then
  echo "$NAME: SKIP — distribution-only (validate-enforcement-map.sh and render-invariant-index.sh live in this repository's own scripts/ and are not shipped to consumers)"
  exit 0
fi

VAL="$ROOT/scripts/validate-enforcement-map.sh"
RENDERER="$ROOT/scripts/render-invariant-index.sh"
SEED="$ROOT/core/fixtures/enforcement-map-sites/seed.sh"

# --- the per-id worker, re-entered through xargs ------------------------------------------
# One process per id so the sweep can use a pool: 94 selected runs at ~0.6 CPU-seconds each is
# a minute of work with nothing shared but two read-only baseline files.
if [ "${1:-}" = "--attrib-one" ]; then
  # One selected run against a mutated tree, recording only whether it produced findings and
  # which. Split out from the sweep worker because the predicate is different -- here a
  # finding is the POINT, there it is the offence.
  at_val="$2"; at_dir="$3"; at_id="$4"
  bash "$at_val" --arms "$at_id" >/dev/null 2>"$at_dir/raw.$at_id"
  if grep -q '^FAIL:' "$at_dir/raw.$at_id"; then
    grep '^FAIL:' "$at_dir/raw.$at_id" | sort > "$at_dir/f.$at_id"
  fi
  rm -f "$at_dir/raw.$at_id"
  exit 0
fi

if [ "${1:-}" = "--sweep-one" ]; then
  sw_val="$2"; sw_out="$3"; sw_err="$4"; sw_dir="$5"; sw_id="$6"
  bash "$sw_val" --arms "$sw_id" > "$sw_dir/o.$sw_id" 2> "$sw_dir/e.$sw_id"
  sw_rc=$?
  hits="$(grep -c -E 'unbound variable|command not found|syntax error' "$sw_dir/e.$sw_id" || true)"
  [ "${hits:-0}" -eq 0 ] || printf '%s\tbroken-slice\t%s\n' "$sw_id" "$(head -1 "$sw_dir/e.$sw_id" | cut -c1-120)"
  [ "$sw_rc" -eq 0 ] || [ "$sw_rc" -eq 1 ] || printf '%s\texit\t%s\n' "$sw_id" "$sw_rc"
  # Every line the selected run prints must be one the full run printed. An EMPTY baseline
  # would make `grep -vxF -f` treat every line as new, so the caller guarantees both baselines
  # are non-empty before dispatching and this asserts it rather than assuming it.
  if [ ! -s "$sw_out" ]; then
    printf '%s\tno-baseline\tthe full run produced empty stdout\n' "$sw_id"
  else
    # ONE stderr line is exempt, by its fixed prefix and nothing looser: the selector's own
    # `--arms NOTE:` naming the unit it actually ran (BL-274). A plain run cannot print it, so
    # without this every id that shares a unit would score not-a-subset. Any OTHER new line still
    # does -- the prefix is anchored and literal.
    grep -v '^validate-enforcement-map: --arms NOTE: ' "$sw_dir/e.$sw_id" > "$sw_dir/e.$sw_id.f" || :
    extra="$( { grep -vxF -f "$sw_out" "$sw_dir/o.$sw_id"; grep -vxF -f "$sw_err" "$sw_dir/e.$sw_id.f"; } | grep -c . || true)"
    [ "${extra:-0}" -eq 0 ] || printf '%s\tnot-a-subset\t%s line(s)\n' "$sw_id" "$extra"
  fi
  exit 0
fi

echo "$NAME fixture"
# The deriver's traced run is evidenced by THIS line reading 1 in its per-fixture log.
echo "inner pool width: $JOBS"
echo

fails=0
RAN=""
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broke() { printf '  FIXTURE BROKEN  %s\n' "$1"; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/${NAME}.XXXXXX")" || { echo "  FIXTURE BROKEN  mktemp failed"; exit 2; }
trap 'rm -rf "$TMP"' EXIT
# THE INNER POOL WIDTH IS DELIBERATELY NARROW. This unit runs inside the suite's 16-way pool,
# and a knob here multiplies against a knob there; six is chosen so the two selected-run sweeps
# (94 ids each, ~0.6 CPU-seconds apiece) do not sit on the critical path while the unit still
# demands well under a third of the box on its own.
#
# AND IT IS NOT THE LEVER, which is why widening it was not the answer to this file becoming
# the pole. Measured solo, the two sweeps together are 23 of 89 seconds; the other 64 are four
# near-full validator runs, each of which is a single serial process no inner pool can touch.
# The directory split above is what those four needed.
#
# JOBS is resolved once, from VAS_INNER_POOL_WIDTH, near the top of this file; both pools read it.

# The declared id set, taken from the SERVED grammar rather than a fresh grep. The reason is
# recorded in render-invariant-index.sh: a column-0 pattern finds 83 of the header-shaped
# lines and a blanks-tolerant one finds 96, and a second region-finder is a second set of bugs.
IDS="$TMP/ids"
bash "$RENDERER" --arm-lines "$VAL" 2>"$TMP/armlines.err" \
  | cut -f2 | tr -s ' /' '\n' | grep -E '^I[0-9]+[a-c]?$' | sort -u > "$IDS"
N_IDS="$(grep -c . "$IDS" || true)"
# A DERIVATION THAT YIELDS NOTHING MUST NOT REPORT SUCCESS. An empty id set makes every sweep
# below iterate zero times and print the same clean lines as a full pass.
if [ "${N_IDS:-0}" -lt 50 ]; then
  broke "derived only ${N_IDS:-0} invariant id(s) from ${RENDERER##*/} --arm-lines; the grammar or the validator moved and every sweep below would be vacuous. stderr: $(head -2 "$TMP/armlines.err")"
fi

# --- THE COVERAGE JOIN, in shard 'a' only --------------------------------------------------
# Sharding moves assertions out of this directory, so the failure it introduces is a phase
# that runs NOWHERE -- a shard directory deleted, a phase name misspelled in one of the lists,
# or a block whose guard was renamed. Every one of those makes the suite report a shorter
# green run, which is this repository's named recurring defect wearing a new hat.
#
# BOTH SIDES ARE DERIVED AND NEITHER IS THE OTHER. The declared side is the PHASES_* lists;
# the live side is grepped from the GUARD LINE of each assertion block, which is the line that
# actually decides whether the block runs. A whole-file grep for the phase name would be
# satisfied by this comment, and a list joined against itself is a tautology.
if [ "$GROUP" = a ]; then
  cov_missing=""
  for _s in $SHARDS; do
    [ "$_s" = a ] && continue
    [ -f "$DIR/../$BASENAME-$_s/run.sh" ] || cov_missing="$cov_missing $_s"
  done
  if [ -n "$cov_missing" ]; then
    broke "shard(s)$cov_missing declared in SHARDS have no driver directory beside this one. Their phases would run NOWHERE and this suite would report a shorter green run."
  fi

  cov_all=""
  for _s in $SHARDS; do
    eval "cov_all=\"\$cov_all \${PHASES_$_s:-}\""
  done
  printf '%s\n' $cov_all | grep -c . > "$TMP/cov.n"
  printf '%s\n' $cov_all | sort -u > "$TMP/cov.declared"
  grep -oE '^if want [a-z0-9-]+; then$' "$0" | awk '{ sub(/;$/, "", $3); print $3 }' | sort -u > "$TMP/cov.sites"
  cov_n="$(cat "$TMP/cov.n")"
  cov_u="$(grep -c . "$TMP/cov.declared" || true)"
  cov_s="$(grep -c . "$TMP/cov.sites" || true)"
  # A GRAMMAR THAT STOPPED MATCHING FINDS NOTHING, and an empty live side agrees with an empty
  # declared side. Floor it rather than let two empties read as a clean join.
  if [ "${cov_s:-0}" -lt 6 ]; then
    broke "the phase-guard grammar found only ${cov_s:-0} 'if want <phase>; then' site(s) in $0; it stopped matching and the coverage join below would compare two sets it did not derive"
  fi
  if [ "$cov_n" -ne "$cov_u" ]; then
    broke "the shard phase lists name $cov_n phase(s) but only $cov_u distinct one(s) — a phase declared in two shards runs twice and the suite reports more assertions than this file makes: $(printf '%s\n' $cov_all | sort | uniq -d | tr '\n' ' ')"
  fi
  if ! cmp -s "$TMP/cov.declared" "$TMP/cov.sites"; then
    broke "the shard phase lists and this file's phase guards disagree — some assertion runs in no shard, or a shard names a phase that no longer exists: $(diff "$TMP/cov.sites" "$TMP/cov.declared" | tr '\n' ' ' | cut -c1-160)"
  fi
  ok "COVERAGE: all $cov_s phase(s) of this fixture are dealt to exactly one of the $(printf '%s\n' $SHARDS | grep -c .) shard(s), each of which has a driver directory"
fi

# --- THE WIDTH KNOB: unset is 6, 1 reaches the pool, a bad value is FIXTURE BROKEN ----------
# Driven through `--print-width`, which prints the very variable both pools read. Each cell is
# presence-shaped -- a specific number or a specific exit must APPEAR -- so a resolver that
# ignored the knob fails the `1` cell, one that ignored the default fails the unset cell, and
# one that accepted anything fails both refusal cells. `env -u` makes the unset cell hold even
# when this fixture itself runs under the deriver, where the knob IS set.
if want width; then
RAN="$RAN width"
w_unset="$(env -u VAS_INNER_POOL_WIDTH bash "$0" --print-width 2>/dev/null)"; w_unset_rc=$?
w_one="$(VAS_INNER_POOL_WIDTH=1 bash "$0" --print-width 2>/dev/null)"; w_one_rc=$?
VAS_INNER_POOL_WIDTH=0 bash "$0" --print-width >/dev/null 2>&1; w_zero_rc=$?
VAS_INNER_POOL_WIDTH=abc bash "$0" --print-width >/dev/null 2>&1; w_abc_rc=$?
# 20 digits overflow `test`, which errors and returns false, so a guard that is only `-lt 1`
# passes it to xargs. 65 is the ceiling's near-miss; 64 must still resolve.
VAS_INNER_POOL_WIDTH=99999999999999999999 bash "$0" --print-width >/dev/null 2>&1; w_big_rc=$?
VAS_INNER_POOL_WIDTH=65 bash "$0" --print-width >/dev/null 2>&1; w_65_rc=$?
w_64="$(VAS_INNER_POOL_WIDTH=64 bash "$0" --print-width 2>/dev/null)"; w_64_rc=$?
if [ "$w_unset_rc:$w_unset" = "0:6" ]; then
  ok "WIDTH: with VAS_INNER_POOL_WIDTH unset the inner pool width resolves to 6"
else
  bad "WIDTH: with VAS_INNER_POOL_WIDTH unset --print-width gave rc $w_unset_rc and '$w_unset' (expected 0 and 6) — the pre-push default moved"
fi
if [ "$w_one_rc:$w_one" = "0:1" ]; then
  ok "WIDTH: VAS_INNER_POOL_WIDTH=1 resolves the inner pool width to 1, so the deriver's knob reaches the pool"
else
  bad "WIDTH: VAS_INNER_POOL_WIDTH=1 gave rc $w_one_rc and '$w_one' (expected 0 and 1) — the deriver's knob does not reach the pool and a traced run stays at full width"
fi
if [ "$w_zero_rc" -eq 2 ] && [ "$w_abc_rc" -eq 2 ]; then
  ok "WIDTH: VAS_INNER_POOL_WIDTH=0 and =abc both exit 2 (FIXTURE BROKEN), never a regression"
else
  bad "WIDTH: a bad width was not refused at exit 2: '0' exited $w_zero_rc, 'abc' exited $w_abc_rc"
fi
if [ "$w_big_rc" -eq 2 ] && [ "$w_65_rc" -eq 2 ] && [ "$w_64_rc:$w_64" = "0:64" ]; then
  ok "WIDTH: a 20-digit width and 65 both exit 2 (FIXTURE BROKEN), and 64 still resolves to 64"
else
  bad "WIDTH: the width ceiling is wrong: 20 digits exited $w_big_rc and 65 exited $w_65_rc (expected 2 and 2); 64 gave rc $w_64_rc and '$w_64' (expected 0 and 64)"
fi

# THE WIDTH IS ALSO CHECKED WHERE THE POOLS USE IT, not only where it is resolved. The cells
# above drive `--print-width`, which reads JOBS at the resolver; a pool that hard-sets its own
# width, or a JOBS re-assigned below the resolver, passes every one of them. This is a
# SOURCE-TEXT check of this file: every pool site reads "$JOBS", there are exactly 2, and JOBS
# is assigned exactly once. Comment lines are skipped. The patterns are assembled from pieces
# (`x''args`, `J''OBS=`) so the text of this check cannot match itself, and no assertion
# message below names the pool command followed by its width flag.
width_sites() { # $1 file; prints "<pool sites> <of which read JOBS> <JOBS assignments>"
  awk -v xa='x''args' -v jb='J''OBS=' '
    /^[[:blank:]]*#/ { next }
    $0 ~ ("(^|[^A-Za-z0-9_])" xa "[[:blank:]][^|]*-P") {
      p++
      if ($0 ~ ("(^|[^A-Za-z0-9_])" xa "[[:blank:]][^|]*-P[[:blank:]]*\"[$]JOBS\"")) j++
    }
    $0 ~ ("(^|[^A-Za-z0-9_])" jb) { a++ }
    END { printf "%d %d %d\n", p, j, a }' "$1"
}
width_sites_ok() { [ "$1" = "2 2 1" ]; }
# SELF-PROBE FIRST, on seeded copies: f1 hard-sets the width at both pool sites, f2 re-assigns
# JOBS just after the --print-width block. Each must FAIL; each copy is cmp-guarded so an edit
# that matched nothing cannot score as a kill.
ws_f1="$TMP/ws.f1.sh"; ws_f2="$TMP/ws.f2.sh"
sed 's/-P "\$JOBS"/-P 6/' "$0" > "$ws_f1"
awk '{ print } prev && $0 == "fi" { print "J" "OBS=6"; prev = 0; next }
     { prev = ($0 ~ /^  printf .*"\$JOBS"; exit 0$/) }' "$0" > "$ws_f2"
ws_real="$(width_sites "$0")"
ws_r1="$(width_sites "$ws_f1")"; ws_r2="$(width_sites "$ws_f2")"
if cmp -s "$0" "$ws_f1" || cmp -s "$0" "$ws_f2"; then
  bad "WIDTH SITES self-probe: a seeded defect copy is byte-identical to this file (f1 changed: $(cmp -s "$0" "$ws_f1" && echo no || echo yes), f2 changed: $(cmp -s "$0" "$ws_f2" && echo no || echo yes)), so the source-text check below is unproven"
elif width_sites_ok "$ws_r1" || width_sites_ok "$ws_r2"; then
  bad "WIDTH SITES self-probe: the source-text check passed a seeded defect: f1 (literal width 6 at both pool sites) read '$ws_r1', f2 (JOBS re-set after --print-width) read '$ws_r2'"
elif width_sites_ok "$ws_real"; then
  ok "WIDTH SITES (source-text check): both pool sites of this file read \"\$JOBS\" and JOBS is assigned once ('$ws_real'); the check refuses f1, a literal width at both sites ('$ws_r1'), and f2, JOBS re-set after --print-width ('$ws_r2')"
else
  bad "WIDTH SITES (source-text check): this file does not have exactly 2 pool sites all reading \"\$JOBS\" with JOBS assigned once — read '$ws_real' as '<sites> <reading JOBS> <assignments>', expected '2 2 1'. A pool that does not read JOBS, or a JOBS re-set after the resolver, makes the --print-width cells above prove nothing about the pools"
fi
fi

# --- Arm 0: CONTROL — the real tree passes a plain run ------------------------------------
# Every "selection reproduced the full run" below is a comparison against this run's output.
# A dirty baseline does not merely weaken them: the verdict block prints its `OK:` line only
# on a clean run, so a failing baseline makes every selected run's summary a line the full run
# never printed and the subset arm reports ninety-four unattributable offenders.
#
# IT IS A PREREQUISITE, NOT A PHASE, and it is paid only by the shard that holds a phase
# needing it. Shard 'b' differentials against the seeded tree instead and never runs this.
if want_any all-ids sweep; then
bash "$VAL" > "$TMP/full.out" 2> "$TMP/full.err"; FULL_RC=$?
if [ "$FULL_RC" -eq 0 ]; then
  ok "plain run of validate-enforcement-map.sh exits 0 (the differentials below are attributable)"
else
  bad "plain run of validate-enforcement-map.sh exits $FULL_RC — the baseline this fixture differentials against is already dirty, so nothing below is evidence about selection: $(grep -m1 '^FAIL:' "$TMP/full.err" | cut -c1-140)"
fi
fi

# --- Arm 1: an id no arm declares must EXIT 2, never 0 having run nothing ------------------
# The whole hazard of a selector is the request that silently matches nothing. `--arms I999`
# must name what it could not find. The control is the same invocation shape with a real id:
# without it this arm would pass against a validator that exits 2 on everything.
first_id="$(head -1 "$IDS")"
if want unknown-id; then
RAN="$RAN unknown-id"
sel_out="$(bash "$VAL" --arms I999 2>&1)"; sel_rc=$?
ctl_out="$(bash "$VAL" --arms "$first_id" 2>&1)"; ctl_rc=$?
case "$sel_rc:$sel_out" in
  2*"no arm declares I999"*) ok "--arms I999 exits 2 and names the id it could not resolve" ;;
  *) bad "--arms I999 exited $sel_rc without naming I999 — a selector that accepts an id nothing declares runs no arm and reports the same line as a clean pass. Output: $(printf '%s' "$sel_out" | head -1)" ;;
esac
if [ "$ctl_rc" -eq 0 ] || [ "$ctl_rc" -eq 1 ]; then
  ok "CONTROL: --arms $first_id (a declared id) exits $ctl_rc, so the arm above discriminates rather than rejecting everything"
else
  bad "CONTROL FAILED: --arms $first_id exited $ctl_rc. The unknown-id arm above cannot be read — a selector that rejects every id would satisfy it too. Output: $(printf '%s' "$ctl_out" | head -1)"
fi
fi

# --- Arm 2: the flag grammar itself fails closed -------------------------------------------
# `--arms` with no value and an unrecognised flag must both be usage failures. A validator
# that treated an empty selection as "run everything" would make every converted battery
# silently pay the full cost and prove nothing about selection.
if want grammar; then
RAN="$RAN grammar"
bash "$VAL" --arms >/dev/null 2>&1; u1_rc=$?
bash "$VAL" --not-a-flag >/dev/null 2>&1; u2_rc=$?
bash "$VAL" --arms "$first_id" extra >/dev/null 2>&1; u3_rc=$?
if [ "$u1_rc" -eq 2 ] && [ "$u2_rc" -eq 2 ] && [ "$u3_rc" -eq 2 ]; then
  ok "--arms with no value, an unknown flag and a trailing operand all exit 2"
else
  bad "the flag grammar does not fail closed: '--arms' exited $u1_rc, '--not-a-flag' exited $u2_rc, a trailing operand exited $u3_rc — each must be 2"
fi
fi

# --- Arm 2b: ONLY ONE HOOK WIDENED — `--arms I66` must fire on exactly that edit ----------
# readset-skip drives whichever pre-push hook it resolves first, so a widening present in one
# copy alone reads green there and reaches only half the population. I66 is the binding. The
# arm lived in readset-skip until that fixture's declaration had to name this validator, which
# no consumer holds; it lives here because this fixture is .dist-only and already drives it.
#
# Two copies holding just what `--arms I66` reads. The CONTROL is unmutated and must read the
# verdict block's OK line at rc 0 -- presence-shaped, so a copy that could not run cannot pass
# it. The MUTANT widens READSET_UNKEYED_TOOLS (the tools exempt from keying, an executable
# line inside the FIXTURE_POOL block I66 joins) in the DISTRIBUTION hook alone; the consumer
# copy is left byte-identical to the control's. The mutation is a literal replacement that must
# match exactly once, and the two dist hooks must then differ, so a lost anchor reads as DID NOT
# APPLY rather than as a kill. The kill is presence-shaped too: non-zero AND the fork message.
if want i66-onehook; then
RAN="$RAN i66-onehook"
I66_FILES="scripts/validate-enforcement-map.sh scripts/render-invariant-index.sh
core/skills/ai-dlc/steps/gate-validation.md core/skills/ai-dlc/enforcement-map.yaml
core/skills/ai-dlc/core-manifest.md core/skills/ai-dlc-update/reconcile/setup-sites.md
.githooks/pre-push core/git-hooks/pre-push core/scripts/hermetic-run.sh"
for _t in i66c i66m; do
  for _f in $I66_FILES; do
    mkdir -p "$TMP/$_t/$(dirname "$_f")" && cp -p "$ROOT/$_f" "$TMP/$_t/$_f" \
      || broke "could not copy $_f into the $_t tree for the I66 arm"
  done
done
I66_FROM='READSET_UNKEYED_TOOLS="node npm npx claude"'
I66_TO='READSET_UNKEYED_TOOLS="node npm npx claude sh"'
I66_N="$(MF="$I66_FROM" MT="$I66_TO" MC="$TMP/i66.n" awk '
  BEGIN { f = ENVIRON["MF"]; t = ENVIRON["MT"]; n = 0 }
  $0 == f { print t; n++; next }
  { print }
  END { print n > ENVIRON["MC"] }' "$TMP/i66c/.githooks/pre-push" > "$TMP/i66m/.githooks/pre-push" && cat "$TMP/i66.n")"
if [ "$I66_N" != 1 ] || cmp -s "$TMP/i66c/.githooks/pre-push" "$TMP/i66m/.githooks/pre-push"; then
  broke "the one-hook I66 mutant DID NOT APPLY: the anchor '$I66_FROM' matched ${I66_N:-?} line(s) of .githooks/pre-push, not 1"
fi
cmp -s "$TMP/i66c/core/git-hooks/pre-push" "$TMP/i66m/core/git-hooks/pre-push" \
  || broke "the one-hook I66 mutant touched the consumer hook too; it must widen ONE copy only"
i66c_out="$(bash "$TMP/i66c/scripts/validate-enforcement-map.sh" --arms I66 2>&1)"; i66c_rc=$?
i66m_out="$(bash "$TMP/i66m/scripts/validate-enforcement-map.sh" --arms I66 2>&1)"; i66m_rc=$?
if [ "$i66c_rc" -eq 0 ] && grep -q '^OK: enforcement-map.yaml in sync' <<< "$i66c_out"; then
  ok "I66 CONTROL: the unmutated copy reads OK at rc 0 under --arms I66, so the mutant verdict below is attributable"
else
  bad "I66 CONTROL: the unmutated copy did not read OK at rc 0 under --arms I66 (rc $i66c_rc): $(printf '%s' "$i66c_out" | head -3 | tr '\n' ' ' | cut -c1-200)"
fi
if [ "$i66m_rc" -ne 0 ] && grep -q 'I66 the two pre-push fixture-suite runners have forked' <<< "$i66m_out"; then
  ok "MUTANT: widening READSET_UNKEYED_TOOLS in .githooks/pre-push alone makes --arms I66 exit $i66m_rc naming the forked runners"
else
  bad "MUTANT SURVIVED: widening READSET_UNKEYED_TOOLS in .githooks/pre-push alone left --arms I66 at rc $i66m_rc without the fork message. A widening in one hook copy reaches only half the population and nothing would say so: $(printf '%s' "$i66m_out" | head -2 | tr '\n' ' ' | cut -c1-200)"
fi
fi

# --- Arm 3: EVERY declared id selected must be BYTE-IDENTICAL to a plain run ---------------
# One line, and it exercises every region boundary at once: preamble, every unit range, and
# the epilogue. If a boundary is off by a line, some arm's body is attributed to its
# neighbour and either runs twice or not at all, and this comparison sees it.
if want all-ids; then
RAN="$RAN all-ids"
ALL="$(tr '\n' ',' < "$IDS" | sed 's/,$//')"
bash "$VAL" --arms "$ALL" > "$TMP/all.out" 2> "$TMP/all.err"; ALL_RC=$?
if [ "$ALL_RC" -eq "$FULL_RC" ] && cmp -s "$TMP/full.out" "$TMP/all.out" && cmp -s "$TMP/full.err" "$TMP/all.err"; then
  ok "--arms with all $N_IDS declared ids is byte-identical to a plain run (stdout, stderr, exit $FULL_RC)"
else
  bad "--arms with every declared id DIFFERS from a plain run (exit $ALL_RC vs $FULL_RC). A region boundary is misplaced, which means some arm's body belongs to its neighbour. $(diff "$TMP/full.out" "$TMP/all.out" 2>&1 | head -3 | tr '\n' ' ')$(diff "$TMP/full.err" "$TMP/all.err" 2>&1 | head -3 | tr '\n' ' ')"
fi
fi

# --- Arm 4: EVERY id alone must run without a broken slice ---------------------------------
# The predicate is the stderr of the selected run, not its findings: on a clean tree the
# findings are empty on both sides and prove nothing (see the header). An arm reading a name a
# skipped unit assigned emits `unbound variable`; a missing function emits `command not
# found`; a mis-sliced region emits a syntax error. All three are invisible to the exit code
# whenever the read happens inside a `$( )`, which is why they are matched by TEXT.
if want sweep; then
RAN="$RAN sweep"
mkdir -p "$TMP/sw"
tr '\n' '\0' < "$IDS" \
  | xargs -0 -n1 -P "$JOBS" bash "$0" --sweep-one "$VAL" "$TMP/full.out" "$TMP/full.err" "$TMP/sw" \
  > "$TMP/sweep.txt" 2>"$TMP/sweep.err"
SWEEP_DONE="$(ls "$TMP/sw" 2>/dev/null | grep -c '^o\.' || true)"
SWEEP_N="$(grep -c . "$TMP/sweep.txt" || true)"
# THE POOL MUST BE ASSERTED TO HAVE RUN. A dispatch that produced no verdicts reports zero
# offenders, which is the same output as a clean sweep.
if [ "${SWEEP_DONE:-0}" -ne "$N_IDS" ]; then
  broke "the sweep dispatched $N_IDS id(s) but only ${SWEEP_DONE:-0} produced output; the pool did not run and a zero below would mean nothing. stderr: $(head -2 "$TMP/sweep.err")"
elif [ "${SWEEP_N:-0}" -eq 0 ]; then
  ok "all $N_IDS ids run alone with no broken slice and no output the full run did not produce"
else
  bad "$SWEEP_N id(s) do not survive being selected alone — a unit reads a value another unit assigns, or a region boundary is wrong: $(head -3 "$TMP/sweep.txt" | tr '\n' '|')"
fi
fi

# --- the seeded tree, and the three mutant copies of it -----------------------------------
# Every mutant is a whole TREE, not a lone script copy: the validator resolves REPO_ROOT from
# its own location, so a copy sitting beside nothing exits 2 with `required input not found`
# and that reads exactly like the mutant being killed.
#
# PREREQUISITE, paid by whichever shard holds a phase that differentials against this tree.
# It is cheap -- measured at under a second -- so it is not what the shard split is about.
T=""
if want_any attrib union partition m1 m2 m3; then
if [ ! -f "$SEED" ]; then
  broke "no seed at $SEED — this fixture builds its mutated tree from enforcement-map-sites' seed and cannot proceed without it"
fi
T="$(bash "$SEED")" || broke "seed.sh failed"
mkdir -p "$T/core/brand-new-subtree" "$T/core/fixtures/zz-arm-selection-probe"
echo 'x' > "$T/core/brand-new-subtree/thing.sh"
echo 'x' > "$T/core/fixtures/zz-arm-selection-probe/run.sh"
TV="$T/scripts/validate-enforcement-map.sh"
fi

# Attribute each finding to an id by asking the SELECTOR, never by reading the message text.
attrib() { # attrib <tree-validator> <tag> <candidate-id-file> -> $TMP/<tag>.ids, $TMP/<tag>.<id>
  local v="$1" tag="$2" cands="$3" id d="$TMP/at.$2"
  rm -rf "$d"; mkdir -p "$d"
  tr '\n' '\0' < "$cands" | xargs -0 -n1 -P "$JOBS" bash "$0" --attrib-one "$v" "$d"
  : > "$TMP/$tag.ids"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    [ -f "$d/f.$id" ] || continue
    printf '%s\n' "$id" >> "$TMP/$tag.ids"
    cp "$d/f.$id" "$TMP/$tag.$id"
  done < "$cands"
}

# GROUPS, NOT IDS. Two ids sharing a unit are byte-identical by construction, so the partition
# claim is about groups of identical output. `groups <tag>` prints `<count>` and leaves one
# representative id per group in $TMP/<tag>.reps.
groups() {
  local tag="$1" id sum
  : > "$TMP/$tag.sums"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    sum="$(cksum < "$TMP/$tag.$id" | tr -d ' ')"
    printf '%s\t%s\n' "$sum" "$id" >> "$TMP/$tag.sums"
  done < "$TMP/$tag.ids"
  sort -u -k1,1 "$TMP/$tag.sums" | cut -f2 > "$TMP/$tag.reps"
  grep -c . "$TMP/$tag.reps" || true
}

# --- Arm 6: the FINDINGS differential, on a tree seeded to make several arms speak ---------
# The clean-tree sweep cannot see this direction. This tree carries two additions -- a new
# core subtree and a new fixture directory -- which between them produce several findings
# across several arms.
#
# PREREQUISITE, and it is the expensive half of shard 'b': one plain run of the seeded tree's
# validator (16s serial) and one 94-id attribution sweep (11s serial), dispatched together. The
# `N_SEEDED < 3` guard inside it is
# THIS SHARD'S CONTROL -- a validator that had stopped running produces no findings on a tree
# seeded to make several arms speak, and the shard reports FIXTURE BROKEN rather than a clean
# differential over an empty set.
#
# THE TWO UNITS RUN CONCURRENTLY, and only the two raw commands are backgrounded. Neither reads
# the other's output: the plain run writes `$TMP/seeded.err`, the sweep writes `$TMP/at.sel` and
# `$TMP/sel.*`, and both only READ the seeded tree -- which is why `seeded.err` lives in `$TMP`
# and never in `$T`, where the sweep would be scanning a file the plain run was still writing.
# Each pid is waited on its own and its status read on the next line; a bare `wait` would
# return 0 over a sweep that died. Every guard and every assignment runs HERE, in the parent,
# after both waits -- a `broke` inside a background job would end the job, not the fixture.
if want_any attrib union partition m2; then
bash "$TV" > /dev/null 2>"$TMP/seeded.err" &
seeded_pid=$!
attrib "$TV" sel "$IDS" &
attrib_pid=$!
wait "$seeded_pid"
seeded_rc=$?
wait "$attrib_pid"
attrib_rc=$?
# The seeded run exits 1 BY DESIGN -- the tree is seeded to produce findings -- so 0 and 1 are
# both a run that completed; anything else is a validator that could not run at all.
if [ "$seeded_rc" -ne 0 ] && [ "$seeded_rc" -ne 1 ]; then
  broke "the seeded tree's plain validator run exited $seeded_rc (0 or 1 expected); the differential below would compare against a run that did not complete. stderr: $(head -2 "$TMP/seeded.err" | cut -c1-140)"
fi
# THE SWEEP'S STATUS IS THE ONLY WITNESS TO ITS DEATH. A sweep killed part-way leaves a partial
# `sel.ids`, and the floors below read a short list exactly as they read a long one.
if [ "$attrib_rc" -ne 0 ]; then
  broke "the seeded tree's attribution sweep exited $attrib_rc; its per-id findings are partial and every differential below would read them as complete"
fi
grep '^FAIL:' "$TMP/seeded.err" | sort > "$TMP/seeded.fails"
N_SEEDED="$(grep -c . "$TMP/seeded.fails" || true)"
if [ "${N_SEEDED:-0}" -lt 3 ]; then
  broke "the seeded tree produced only ${N_SEEDED:-0} finding(s); this differential needs at least three arms speaking at once and the mutation no longer reaches them"
fi
N_ATTRIB="$(grep -c . "$TMP/sel.ids" || true)"
N_GROUPS="$(groups sel)"
fi

if want attrib; then
RAN="$RAN attrib"
if [ "${N_ATTRIB:-0}" -lt 3 ]; then
  bad "the seeded tree produced $N_SEEDED finding(s) under a full run but only ${N_ATTRIB:-0} id(s) reproduce any of them when selected alone — findings are being LOST by selection, which is the failure this fixture exists to catch"
else
  ok "$N_SEEDED seeded finding(s) attribute to $N_ATTRIB id(s), each reproduced by its own --arms run"
fi
fi

# The union of the per-id findings must equal the full run's. A selector that dropped an arm
# satisfies neither this nor the group arm below; a selector that ignores its argument
# satisfies this one and fails the next, which is why both are here.
if want union; then
RAN="$RAN union"
: > "$TMP/union"
while IFS= read -r id; do [ -n "$id" ] && cat "$TMP/sel.$id" >> "$TMP/union"; done < "$TMP/sel.ids"
sort -u "$TMP/union" -o "$TMP/union"
if cmp -s "$TMP/union" "$TMP/seeded.fails"; then
  ok "the union of the per-arm findings equals the full run's findings exactly"
else
  bad "the union of the per-arm findings differs from the full run's: $(diff "$TMP/seeded.fails" "$TMP/union" | head -2 | cut -c1-110 | tr '\n' ' ')"
fi
fi

if want partition; then
RAN="$RAN partition"
overlap=0
while IFS= read -r a; do
  while IFS= read -r b; do
    [ "$a" = "$b" ] && continue
    if [ -n "$(comm -12 "$TMP/sel.$a" "$TMP/sel.$b" 2>/dev/null)" ]; then
      overlap=$((overlap + 1))
    fi
  done < "$TMP/sel.reps"
done < "$TMP/sel.reps"
if [ "${N_GROUPS:-0}" -ge 3 ] && [ "$overlap" -eq 0 ]; then
  ok "the $N_ATTRIB reporting id(s) fall into $N_GROUPS disjoint output groups — selection restricts what runs rather than relabelling it"
else
  bad "selection did not partition the findings: $N_GROUPS distinct output group(s) (floor 3) and $overlap overlapping pair(s). A selector that runs more than it was asked for collapses every group into one and makes each battery's per-arm number a measurement of the whole file"
fi
fi

# --- Arm 5: THE MUTANT for arm 4. An ABSENCE-shaped arm requires one ----------------------
# Arm 4 reports the number of offending ids and that number is normally zero, which is what a
# scan that opened no file also reports. Put ONE hoisted value back inside the arm that used
# to assign it and arm 4's predicate must name the reader. Measured shape: `TEMPLATE` is
# assigned in I13's unit and read by I14's, and before the hoist `--arms I14` died with
# `TEMPLATE: unbound variable`.
if want m1; then
RAN="$RAN m1"
TM1="$TMP/m1"
cp -R "$T" "$TM1"
awk '
  /^TEMPLATE="\$REPO_ROOT\/templates\/settings\.json\.template"/ && !done { done = 1; next }
  { print }
' "$TV" > "$TM1/scripts/validate-enforcement-map.sh.mut"
if cmp -s "$TV" "$TM1/scripts/validate-enforcement-map.sh.mut"; then
  broke "the arm-4 mutant changed nothing — the hoisted TEMPLATE assignment was not found, so this control tests a clean file"
fi
mv "$TM1/scripts/validate-enforcement-map.sh.mut" "$TM1/scripts/validate-enforcement-map.sh"
bash "$TM1/scripts/validate-enforcement-map.sh" --arms I14 >/dev/null 2>"$TMP/m1.err"
if grep -q 'TEMPLATE: unbound variable' "$TMP/m1.err"; then
  ok "MUTANT: un-hoisting TEMPLATE makes --arms I14 report 'TEMPLATE: unbound variable', so arm 4's predicate can fire"
else
  bad "MUTANT SURVIVED: un-hoisting TEMPLATE did NOT make --arms I14 emit an unbound-variable error. Arm 4 above cannot distinguish a sound slice from a broken one and its clean report means nothing. stderr: $(head -1 "$TMP/m1.err" | cut -c1-120)"
fi
fi

# --- Arm 7: THE MUTANT for arm 6 -----------------------------------------------------------
# Neuter the emission test so `--arms` keeps every line, and the group arm above must go red:
# every id then reports the whole finding set and the group count collapses to one. Without
# this, "the findings partition" is satisfied by a selector that works and equally by a fixture
# that compared nothing.
#
# THE MUTANT IS RUN ONLY OVER THE GROUP REPRESENTATIVES, and that is a cost decision with a
# correctness argument attached rather than a shortcut. A neutered selector runs the WHOLE
# file on every call, so sweeping all 94 ids here would cost ~1800 CPU-seconds -- more than
# this fixture is meant to save. The representatives are exactly the ids the arm above found
# to differ from each other, so if the mutant fails to collapse them it fails to collapse
# anything, and the floor is the same one arm 6 is judged by.
if want m2; then
RAN="$RAN m2"
TM2="$TMP/m2"
cp -R "$T" "$TM2"
awk '{ sub(/if \(ln < ustart\[1\] \|\| ln >= verdict \|\| \(ln in keep\)\) print l/, "print l"); print }' \
  "$TV" > "$TM2/scripts/validate-enforcement-map.sh.mut"
if cmp -s "$TV" "$TM2/scripts/validate-enforcement-map.sh.mut"; then
  broke "the arm-7 mutant changed nothing — the emission line in ARMS_SELECT_AWK was not found, so this control tests an unmutated selector"
fi
mv "$TM2/scripts/validate-enforcement-map.sh.mut" "$TM2/scripts/validate-enforcement-map.sh"
attrib "$TM2/scripts/validate-enforcement-map.sh" m2 "$TMP/sel.reps"
M2_GROUPS="$(groups m2)"
if [ "${M2_GROUPS:-0}" -lt "$N_GROUPS" ]; then
  ok "MUTANT: a selector that keeps every unit collapses the $N_GROUPS group representative(s) into ${M2_GROUPS:-0} output group(s), so arm 6's partition predicate can fire"
else
  bad "MUTANT SURVIVED: a selector stripped of its keep-range test still produced ${M2_GROUPS:-0} distinct output groups out of $N_GROUPS representatives. Arm 6's partition check cannot fire and its clean report means nothing"
fi
fi

# --- Arm 8: an arm that cannot EMIT must be unconstructible, not merely unchecked ----------
# `--arms` runs no silent-arm check of its own. It does not need one: `--arm-lines` runs the
# renderer's totality assertions before it prints a line, so a declared arm with no
# err/warn/fail call fails there and `--arms` exits 2. That is a partition rather than a
# check, and a partition still has to be shown to hold -- a renderer that stopped asserting it
# would leave `--arms` selecting an arm that can never speak, which passes forever.
if want m3; then
RAN="$RAN m3"
TM3="$TMP/m3"
cp -R "$T" "$TM3"
{ cat "$TV"; printf '\n# --- I998: a declared arm with no emitter ------------------------------------\n:\n'; } \
  > "$TM3/scripts/validate-enforcement-map.sh"
bash "$TM3/scripts/validate-enforcement-map.sh" --arms I998 >/dev/null 2>"$TMP/m3.err"; m3_rc=$?
if [ "$m3_rc" -eq 2 ] && grep -q 'no err/warn/fail call' "$TMP/m3.err"; then
  ok "MUTANT: an arm declared with no emitter makes --arms exit 2 naming the silent arm, so a fixture cannot select an arm that could never fire"
else
  bad "MUTANT SURVIVED: adding a declared arm with no err/warn/fail call left --arms exiting $m3_rc. A battery could select an invariant that cannot emit, and that fixture would pass forever. stderr: $(head -1 "$TMP/m3.err" | cut -c1-120)"
fi
fi

[ -n "$T" ] && rm -rf "$T"

# EVERY PHASE THIS SHARD WAS DEALT MUST HAVE RUN. A `want` that stopped matching -- a renamed
# phase, a typo in a PHASES_ list, a guard edited out -- silently drops assertions, and a
# shorter clean run reads exactly like a full one. The coverage join above binds the two SETS;
# this binds what actually EXECUTED to the set this shard holds.
ran_n="$(printf '%s\n' $RAN | grep -c . || true)"
mine_n="$(printf '%s\n' $MINE | grep -c . || true)"
if [ "${ran_n:-0}" -ne "${mine_n:-0}" ]; then
  broke "shard '$GROUP' was dealt $mine_n phase(s) [$MINE] but only ${ran_n:-0} executed [$RAN]; the rest asserted nothing and this run's clean lines are a shorter report, not a passing one"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "$NAME: PASS"
  exit 0
fi
echo "$NAME: $fails FAILED"
exit 1
