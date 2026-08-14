#!/usr/bin/env bash
# validator-arm-selection-b — shard 'b' of the validator-arm-selection phase set.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The assertions, the seed, the mutant
# discipline and the reasoning all live in the sibling's run.sh; what this directory buys is a
# unit the pre-push pool can start on its own. That suite is POLE-BOUND — its makespan tracks
# its single longest DIRECTORY, and `core/fixtures/*/run.sh` is what it globs — so the
# sibling's 220s was the whole suite's wall clock, and the 6-way pool already inside that one
# directory could not change it.
#
# THE SPLIT IS ON THE PREREQUISITE BOUNDARY, not round-robin. The sibling's phases fall into
# two clusters: four differential against a plain-tree validator run, six against a SEEDED
# tree. Dealing them out in turn would make both shards pay both prerequisites; splitting on
# the cluster boundary means each is computed exactly once, so this shard costs no extra CPU.
# This directory holds the seeded-tree cluster.
#
# The shard set and the partition are declared in the sibling, joined against the phase guards
# grepped out of that same file, and checked by shard 'a': a phase named in no shard, a phase
# named in two, and a declared shard with no driver directory all fail the build there. So
# deleting this file cannot quietly shrink the suite.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree —
# the same resolution `enforcement-map-sites-b` uses, and the one I33 permits.
#
# Usage: run.sh
# Exit:  0 = every phase in this shard holds, 1 = one regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../validator-arm-selection/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling validator-arm-selection/run.sh not found — shard 'b' has no phases to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b
