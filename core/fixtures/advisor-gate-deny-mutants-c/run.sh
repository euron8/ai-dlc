#!/usr/bin/env bash
# advisor-gate-deny-mutants-c — shard 'c' of the advisor-gate-deny mutation battery.
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
  echo "FIXTURE ERROR: sibling advisor-gate-deny-mutants/run.sh not found — shard 'c' has no mutants to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

# The REQUIRED input of inputs.decl: the shared lib resolves this hook from the same root and
# every mutant of the battery is a copy of it.
HOOKP="$(cd "$HERE/../.." && pwd)/hooks/ai-dlc-advisor-gate.sh"
echo "HERMETIC-CONSUMED $HOOKP"
# The sibling battery copies the provenance file beside every mutant; that cp is in the sibling.
PROVP="$(cd "$HERE/../.." && pwd)/hooks/ai-dlc-context-provenance.sh"
echo "HERMETIC-CONSUMED $PROVP"

exec bash "$IMPL" --group c
