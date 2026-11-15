#!/usr/bin/env bash
# procsub-staged-refusal-b -- shard 'b' of the procsub-staged-refusal fixture.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. Every arm and control lives in the
# sibling's run.sh; this directory is a unit the pre-push pool can start on its own, because the
# unsharded fixture was one very large directory. The partition is declared in the sibling and joined
# there (J0) against the sibling's own unit guards, in every shard.
#
# Resolved as a SIBLING inside core/fixtures/. Run from the project root, never from this directory.
# Exit: 0 every unit dealt to this shard passes, 1 one does not, 2 broken.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../procsub-staged-refusal/run.sh"
[ -f "$IMPL" ] || { echo "FIXTURE ERROR: sibling procsub-staged-refusal/run.sh not found -- shard 'b' has nothing to run, and a shard that runs nothing passes everything it never checked" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/procsub-staged-refusal/run.sh"
exec bash "$IMPL" --group b
