#!/usr/bin/env bash
# derivation-capture-mutants-d — shard 'd' of the derivation-capture mutation battery.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The mutants, the deal and the coverage
# join all live in the sibling derivation-capture-mutants/run.sh; this directory buys a unit the
# pre-push pool can start on its own, because that suite is POLE-BOUND on its longest directory.
# Every shard runs the join itself, so no shard passes without it.
#
# Usage: run.sh
# Exit:  0 = every mutant dealt to this shard is killed by exactly its arms, 1 = one is not,
#        2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../derivation-capture-mutants/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling derivation-capture-mutants/run.sh not found — shard 'd' has no mutants to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}
exec bash "$IMPL" --group d
