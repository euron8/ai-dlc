#!/bin/bash
# Hand trace of the value positive control, independent of value.py: graph s322 stories pass 1, shard 1, F-2
# ("AC3's old-name fence names its four sibling literals without listing or locating them"). Its repair says AC3
# now spells all five -e literals of the Story 3.3 AC4 fence and cites story-3-3-...md:93. Reads the shipped story
# at the given ref and counts each literal; the old phrase and an absent token must read 0.
#   bash docs/analysis/step-value-b256/bl398/hand-trace.sh <graph clone> [ref=ed61de745]
set -u
G=$1
REF=${2:-ed61de745}
F=_bmad-output/planning-artifacts/s322/stories/story-1-1-story-5-6-closeout-observation-and-predicate.md
S=$(git -C "$G" show "${REF}:${F}") || exit 2
for lit in 'its four sibling literals' 'the five-literal fence of' 'CDK_SVC_FRAGMENT="Rebalancer"' \
  "serviceArns[?contains(@, 'Rebalancer')]" 'grep -i "$pattern" | head -1' 'grep -qi "rebalancer"' \
  'grep -i "rebalancer"' 'story-3-3-deploy-and-ops-scripts-handle-two-instances.md:93' 'zq-bl398-absent-token'; do
  n=$(/usr/bin/grep -c -F -- "$lit" <<<"$S") || n=0
  printf '%s\t%s\n' "$n" "$lit"
done
