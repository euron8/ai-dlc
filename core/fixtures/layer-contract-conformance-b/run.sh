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
# THIS SHARD IS `.dist-only`, LIKE enforcement-map-sites-b, AND SO IS ITS SIBLING. A shard's
# packaging is its sibling's packaging, and the sibling's subject, validate-enforcement-map.sh,
# is not shipped. Both directories once shipped and SKIPped on every consumer, which the
# consumer's pool recorded as two `ok` verdicts over nothing tested; the markers stop that.
# I116 refuses a shipped user of a sibling that does not ship, so the two must move together.
# The SKIP in the sibling stays, for a consumer still holding a copy installed before the
# markers, and its shard protocol stays placed AFTER that SKIP for the same reason.
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
