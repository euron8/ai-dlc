#!/usr/bin/env bash
# advisor-gate-deny-mutants-d — shard 'd' of the advisor-gate-deny mutation battery.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The mutants, the control, the deal and
# the coverage join all live in the sibling advisor-gate-deny-mutants/run.sh; this directory buys
# a unit the pre-push pool can start on its own, because that suite is POLE-BOUND on its longest
# directory. Every shard runs the join and the control itself, so no shard passes without them.
#
# Usage: run.sh
# Exit:  0 = every mutant dealt to this shard is killed by exactly its arms, 1 = one is not,
#        2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../advisor-gate-deny-mutants/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling advisor-gate-deny-mutants/run.sh not found — shard 'd' has no mutants to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

for _h in ai-dlc-advisor-gate.sh ai-dlc-context-provenance.sh; do
  echo "HERMETIC-CONSUMED $(cd "$HERE/../../hooks" && pwd)/$_h"
done
exec bash "$IMPL" --group d
