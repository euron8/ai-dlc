#!/usr/bin/env bash
# fold-architect-ledger-join-mutants-b — shard 'b' of the fold-architect-ledger-join mutation
# battery.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The mutants, the controls, the M6
# premise and the reasoning all live in the sibling's run.sh; what this directory buys is a unit
# the pre-push pool can start on its own. That suite is POLE-BOUND (its makespan tracks its
# single longest DIRECTORY, and `core/fixtures/*/run.sh` is what it globs), so the unsharded
# battery would have been the whole suite's wall clock.
#
# The shard set and the mutant partition are declared in the sibling and joined there against
# the `run_mutant` lines of that same file. Every shard runs that join, the controls and the
# premise itself, so no shard can pass without them, and a shard declared with no driver
# directory fails the build in all three.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree.
#
# Usage: run.sh
# Exit:  0 = every mutant dealt to this shard is killed by exactly its arms, 1 = one is not,
#        2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../fold-architect-ledger-join-mutants/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling fold-architect-ledger-join-mutants/run.sh not found — shard 'b' has no mutants to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b
