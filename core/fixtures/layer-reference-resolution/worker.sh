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

report() { printf '%s\n' "$1" > "$outdir/$label"; exit 0; }

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
