#!/usr/bin/env bash
# advisor-gate-deny-mutants-e — shard 'e' of the advisor-gate-deny mutation battery.
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
# The pre-push gate exports AI_DLC_* tunables; none is read here, but scrub them all the same.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
IMPL="$HERE/../advisor-gate-deny-mutants/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling advisor-gate-deny-mutants/run.sh not found — shard 'e' has no mutants to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

# The sibling battery's seed.sh is the first USER of both hooks (it locates them from the root this
# driver resolves); the sentinels are printed here because that sibling is shared by all five shards.
ROOT="$(cd "$HERE/../../.." && pwd)"
for _h in core/hooks/ai-dlc-advisor-gate.sh core/hooks/ai-dlc-context-provenance.sh; do
  echo "HERMETIC-CONSUMED $_h"
done
exec bash "$IMPL" --group e
