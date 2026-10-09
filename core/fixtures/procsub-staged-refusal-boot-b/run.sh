#!/usr/bin/env bash
# procsub-staged-refusal-boot-b -- shard 'b' of the procsub-staged-refusal-boot fixture.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. Every world, cell and mutant lives in the
# sibling's run.sh; this directory is a unit the pre-push pool can start on its own, because that suite
# is POLE-BOUND. The shard split and the coverage join over it are declared in the sibling, and every
# shard runs that join, so a shard declared with no driver directory fails the join in all three.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree.
#
# Usage: run.sh
# Exit:  0 = every unit dealt to this shard passes, 1 = one does not, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../procsub-staged-refusal-boot/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling procsub-staged-refusal-boot/run.sh not found -- shard 'b' has nothing to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b
