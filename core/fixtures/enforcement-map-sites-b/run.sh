#!/usr/bin/env bash
# enforcement-map-sites-b — shard 'b' of the enforcement-map-sites assertion set.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The assertions, the seed, the
# mutation discipline and the reasoning all live in the sibling's run.sh; what this directory
# buys is a unit the pre-push pool can start on its own. That suite is POLE-BOUND — its
# makespan tracks its single longest DIRECTORY, and `core/fixtures/*/run.sh` is what it
# globs — so the sibling's 253s was the whole suite's wall clock at every outer pool size
# from 4 to 16, and an 8-way pool inside one directory could not change that.
#
# The shard set and the round-robin partition are declared in the sibling, derived from its
# own assertion list, and joined: shard 'a' fails the build if a declared shard has no
# driver directory beside it, so deleting this file cannot quietly shrink the suite.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree —
# the same resolution `trunk-audit-mutants` uses for its own subject fixture, and the one
# I33 permits.
#
# Usage: run.sh
# Exit:  0 = every assertion in this shard holds, 1 = one regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../enforcement-map-sites/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling enforcement-map-sites/run.sh not found — shard 'b' has no assertions to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b
