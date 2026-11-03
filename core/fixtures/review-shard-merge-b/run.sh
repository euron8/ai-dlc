#!/usr/bin/env bash
# review-shard-merge-b -- shard 'b' of the review-shard-merge fixture (BL-906).
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. Every world, arm, mutant and control lives in the
# sibling's run.sh and lib.sh; what this directory buys is a unit the pre-push pool can start on its own, because
# the suite is POLE-BOUND and the unsharded fixture was its longest directory. The shard split, the units each shard
# runs and the coverage join over them (J0) are declared in the sibling, and both shards run that join and the seed,
# so no shard passes without them and a shard declared with no driver directory fails the join in both.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree.
#
# Usage: run.sh [--matrix | --merge-slices <slice output>...]  (passed to the sibling after --group b)
# Exit:  0 = every unit dealt to this shard passes, 1 = one does not, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../review-shard-merge/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling review-shard-merge/run.sh not found -- shard 'b' has nothing to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b "$@"
