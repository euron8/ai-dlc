#!/usr/bin/env bash
# layer-contract-conformance-b — shard 'b' of the layer-contract-conformance assertion set.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The mutants, the registries, the
# mutation discipline and the reasoning all live in the sibling's run.sh; what this directory
# buys is a unit the pre-push pool can start on its own. That suite is POLE-BOUND — its
# makespan tracks its single longest DIRECTORY, and `core/fixtures/*/run.sh` is what it globs
# — so the sibling's recorded 434 pool-seconds put it in the pole set, and the 8-way pool it
# already ran inside one directory could not change that.
#
# WHAT IS PARTITIONED IS THE VALIDATOR RUNS, NOT THE ASSERTIONS. The sibling's two registries
# are many-to-one: three arms read the unmutated `control` run and one reads another mutant's
# run, so dealing assertions out would separate an arm from the run whose output it reads.
# The sibling deals `$RUNS` out round-robin instead, gives every shard the control, and
# refuses to pass in shard 'a' if a declared shard has no driver directory beside it — so
# deleting this file cannot quietly shrink the suite.
#
# THIS SHARD SHIPS, AND THAT IS THE OPPOSITE OF enforcement-map-sites-b. It carries NO
# `.dist-only` marker, because a shard's packaging is its sibling's packaging and the sibling
# ships: it is named in scripts/uninstall.sh's removal loop and in both core_manifest copies,
# and I8 joins all three against the derived shippable set in both directions. What makes that
# safe on a consumer is the sibling's own SKIP — validate-enforcement-map.sh is
# distribution-only, so the resolution there finds nothing and both directories declare
# themselves inapplicable and exit 0. The sibling's shard protocol is deliberately placed
# AFTER that SKIP so this stays true no matter which directories a consumer received.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree —
# the same resolution `trunk-audit-mutants` uses for its own subject fixture, and the one
# I33 permits.
#
# Usage: run.sh
# Exit:  0 = every assertion in this shard holds, 1 = one regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../layer-contract-conformance/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling layer-contract-conformance/run.sh not found — shard 'b' has no assertions to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b
