#!/usr/bin/env bash
# check-24-adversarial-convergence-b -- shard 'b' of the check-24-adversarial-convergence fixture.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. Every case, mutant and control lives in the
# sibling's run.sh; what this directory buys is a unit the pre-push pool can start on its own, because
# that suite is POLE-BOUND and the unsharded fixture was its longest directory. The shard split, the units
# each shard runs and the coverage join over them are declared in the sibling, and every shard runs that
# join and the seed, so no shard passes without them and a shard declared with no driver directory fails
# the join in all four.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree.
#
# Usage: run.sh
# Exit:  0 = every unit dealt to this shard passes, 1 = one does not, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../check-24-adversarial-convergence/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling check-24-adversarial-convergence/run.sh not found -- shard 'b' has nothing to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b
