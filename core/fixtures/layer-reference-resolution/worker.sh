#!/usr/bin/env bash
# worker.sh — score ONE mutant, under the inner pool. Invoked by run.sh's Part 5 through
# `xargs -P`, once per mutant, never by hand.
#
# Usage: worker.sh <label> <exprfile> <wantfile> <linter> <cons> <domain> <outdir>
# Writes: "$outdir/$label" — ALWAYS, on every exit path. Prints nothing.
#
# WHY A FILE AND NOT STDOUT. `made=$((made+1))` inside a pooled child is lost to the
# subshell (`tool-hazards.md`), so the parent cannot count what the children asserted by
# letting them print. Each child records its own verdict where the parent can collect it
# by NAME, and run.sh walks the DISPATCHED LIST rather than the directory listing — a
# worker that died leaves no file, and walking the list is what makes that visible.
#
# EVERY EXIT PATH WRITES. A worker that returns without writing is indistinguishable from
# one that was never dispatched, and the collector would then have to guess. The three
# outcomes it can report are KILL, SURVIVED and BROKEN; anything else — a `set -u` abort,
# a signal, a `sed` that dies — leaves the file ABSENT and the collector reports it as a
# lost worker against the dispatched list.
#
# THE EXPRESSION ARRIVES IN A FILE, NOT AS AN ARGUMENT. The mutation expressions carry
# backslashes, `$`, backticks and embedded quotes; passing one through `xargs` and a second
# shell would re-interpret it, and a `sed` expression that is silently altered still RUNS —
# it just mutates something else, or nothing, which `cmp -s` reports as "matched NOTHING"
# and reads as a broken fixture rather than a mangled argument. run.sh writes each
# expression with printf '%s' and the worker reads it back verbatim.
set -uo pipefail

label="${1:?worker: missing label}"
exprfile="${2:?worker: missing exprfile}"
wantfile="${3:?worker: missing wantfile}"
LINTER="${4:?worker: missing linter}"
CONS="${5:?worker: missing consumer root}"
DOMAIN="${6:?worker: missing domain path}"
outdir="${7:?worker: missing outdir}"

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/vector.sh"

# The mutant is a COPY, per `fixture-mutants.md`, and it is built in its OWN directory so
# two pooled workers cannot race on one path. A shared $ROOT/mutant-<label>.sh would be
# unique per label already, but the .new temporary would not be if a label ever repeated.
work="$outdir/.work-$label"
mkdir -p "$work"
m="$work/mutant.sh"

# THE WORKER COUNTS ITS OWN PEERS IN FLIGHT, and that is not bookkeeping: it is the only
# evidence that the pool was CONCURRENT. A probe reading the width VARIABLE is satisfied by
# `xargs -P 1` beside a `MUT_JOBS=6` that nothing joins to the dispatch — measured, an
# adversary closed the receipt that way at 132.3s and 125% CPU while the probe still printed
# "dispatched at width 6".
#
# AND A WALL-CLOCK OVERLAP TEST DOES NOT WORK EITHER, measured on the first repair: `date +%s`
# is whole seconds, so a worker ending at T and the next starting at T read as overlapping and
# a fully SERIAL run reported 2 in flight. The marker is presence, not time — a live marker
# file per running worker, counted while this one is running, so an interval that merely
# ABUTS another cannot be mistaken for one that overlaps it.
# AND A MARKER FILE IS NOT A LIVE WORKER, WHICH TOOK THREE CUTS TO STATE CORRECTLY. Each wrong
# version counted something ADJACENT to "a peer worker is running right now":
#
#   counting FILES        — a killed worker's leftover inflates it. Measured: five seeded
#                           stale markers made a SERIAL dispatch report 6 and PASS.
#   PID is LIVE           — closes the DEAD-pid hole and not the LIVE-pid one. Measured: one
#                           marker named with run.sh's own pid, alive by construction for the
#                           whole run, made a SERIAL dispatch report 2 and PASS.
#   PID is live AND MINE  — this. A marker counts only if it carries the run-scoped nonce
#                           run.sh generated for THIS dispatch, so neither a leftover from an
#                           earlier run nor a file named for any other live process qualifies.
#
# The nonce is not a secret and does not need to be: its whole job is to make the marker's
# identity PROVABLE rather than inferred from a name anything can choose.
inflight_dir="$outdir/.inflight"
mkdir -p "$inflight_dir"
printf '%s\n' "${MUT_NONCE:?worker: missing MUT_NONCE}" > "$inflight_dir/$$"
peers=0
for _p in "$inflight_dir"/*; do
  [ -f "$_p" ] || continue
  _pid="${_p##*/}"
  case "$_pid" in ''|*[!0-9]*) continue ;; esac
  kill -0 "$_pid" 2>/dev/null || continue          # not a live process
  grep -qxF "$MUT_NONCE" "$_p" 2>/dev/null || continue   # live, but not one of MY peers
  peers=$((peers+1))
done

report() {
  rm -f "$inflight_dir/$$"
  { printf '%s\n' "$1"
    printf 'inflight %s\n' "$peers"
  } > "$outdir/$label"
  exit 0
}

cp "$LINTER" "$m" || report "BROKEN could not copy the linter"

expr="$(cat "$exprfile")"
if ! sed -E "$expr" "$m" > "$m.new"; then
  # A `sed` that DIES is a mutant that never existed, and it must not read as a survivor.
  report "BROKEN the sed expression did not apply"
fi
mv "$m.new" "$m"

# `cmp -s` guard: a sed that matched nothing cannot pass as a mutation.
if cmp -s "$LINTER" "$m"; then
  report "BROKEN the sed matched NOTHING, so this arm proved nothing"
fi

want="$(cat "$wantfile")"
got="$(vector "$m" "$CONS")"

if [ "$got" = "$want" ]; then
  report "KILL $got"
fi
report "SURVIVED got [$got] want [$want]"
