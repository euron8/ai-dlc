#!/usr/bin/env bash
# remediator-shard-join-b -- shard 'b' of the remediator-shard-join fixture (BL-1095).
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. Every arm and control lives in the sibling's run.sh,
# lib.sh and unit-*.sh; what this directory buys is a unit the pre-push pool can start on its own, because the suite
# is POLE-BOUND and the unsharded fixture was one of its longest directories. The shard split, the units each shard
# runs and the coverage join over them are declared in the sibling, and both shards run that join, so a shard
# declared with no driver directory fails the join in both.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree.
#
# Usage: run.sh
# Exit:  0 = every unit dealt to this shard passes, 1 = one does not, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../remediator-shard-join/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling remediator-shard-join/run.sh not found -- shard 'b' has nothing to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b
