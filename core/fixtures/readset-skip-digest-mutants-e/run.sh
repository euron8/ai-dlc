#!/usr/bin/env bash
# readset-skip-digest-mutants-e -- shard 'e' of the readset-skip-digest-mutants mutation battery.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The mutants, the controls and the reasoning all
# live in the sibling's run.sh (the controls run in shard a only, bound by J2 and held to this shard by D14); this directory is a unit the pre-push pool can start on its own, because
# that suite is pole-bound and the unsharded battery was its longest directory. The partition is declared
# in the sibling and joined there (J0) against the sibling's own mutant lines, in every shard.
#
# Resolved as a SIBLING inside core/fixtures/. Run from the project root, never from this directory.
# Exit: 0 every mutant dealt to this shard is killed by exactly its worlds, 1 one is not, 2 broken.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../readset-skip-digest-mutants/run.sh"
[ -f "$IMPL" ] || { echo "FIXTURE ERROR: sibling readset-skip-digest-mutants/run.sh not found -- shard 'e' has no mutants to run, and a shard that runs nothing passes everything it never checked" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/readset-skip-digest-mutants/run.sh"
exec bash "$IMPL" --group e
