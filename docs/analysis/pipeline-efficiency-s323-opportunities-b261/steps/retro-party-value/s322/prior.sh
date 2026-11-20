#!/bin/bash
# usage: prior.sh TOKEN ; searches tree at retro PR for pre-party places (git -C graph)
cd /Users/n8/git/graph; R=78817f315
for t in "$@"; do
 echo "=== $t"
 # (a) committed earlier than sprint PR e0ebaf019 (before 2026-11-12T02:39)
 echo -n "history -S first commit: "; git log --all -S"$t" --format='%h %aI %s' --reverse -- . ':(exclude)_bmad-output/party-mode-transcripts' ':(exclude)docs/retro/s322' | head -2 | cut -c1-120 | tr '\n' '|'; echo
 for f in _bmad-output/implementation-artifacts/gate-log.md docs/escalations/pending.md docs/escalations/pending-archive.md _bmad-output/planning-artifacts/carry-over-backlog.md _bmad-output/implementation-artifacts/sprint-status.yaml; do
  n=$(git show "$R:$f" 2>/dev/null | grep -c -F -- "$t"); echo "  $f: $n"
 done
 echo -n "  docs/reviews+s322 artifacts files: "; git grep -l -F -- "$t" $R -- 'docs/reviews' '_bmad-output/implementation-artifacts/s322' '_bmad-output/planning-artifacts/s322' | sed "s/^$R://" | head -6 | tr '\n' ' '; echo
done
