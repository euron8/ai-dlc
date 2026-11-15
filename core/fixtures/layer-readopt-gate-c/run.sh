#!/usr/bin/env bash
# layer-readopt-gate-c -- shard 'c' of the layer-readopt-gate fixture.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. Every case lives in the sibling's run.sh; what
# this directory buys is a unit the pre-push pool can start on its own, because that suite is POLE-BOUND and the
# unsharded fixture was one of its longest directories. The shard split, the units each shard runs and the coverage
# join over them are declared in the sibling, and every shard runs that join, so a shard declared with no driver
# directory fails the join in all five.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree.
#
# Usage: run.sh
# Exit:  0 = every unit dealt to this shard passes, 1 = one does not, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../layer-readopt-gate/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling layer-readopt-gate/run.sh not found -- shard 'c' has nothing to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group c
