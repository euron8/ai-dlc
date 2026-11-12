#!/bin/bash
# BL-398 measurement, batch 256. Reproduce from the repo root:
#   bash docs/analysis/step-value-b256/bl398/run.sh <scratch dir> <graph clone>
# Runs extract.py + analyze.py serially at three window ends into <scratch dir>/out10, /out09 and /outb251 (each
# skipped when its steps.csv is already there), then cost.py and value.py, writing cost.txt and value.txt beside
# this script. Reads transcripts at ~/.claude/projects/-Users-n8-git-graph (or $EXTRACT_ROOT) and the graph clone,
# read only; writes nothing else.
set -u
D=$1
G=$2
H=$(cd "$(dirname "$0")" && pwd)
# The repo root: walk up from this script until a directory holds both .git and docs/backlog.md.
R=$H
while [ "$R" != "/" ] && ! { [ -e "$R/.git" ] && [ -f "$R/docs/backlog.md" ]; }; do R=$(dirname "$R"); done
[ "$R" != "/" ] || { echo "run.sh: no repo root (.git plus docs/backlog.md) above $H" >&2; exit 2; }
X=$R/docs/analysis/pipeline-efficiency-s317-s320/scripts
A=$R/docs/analysis/pipeline-efficiency-s317-s318/scripts
for pair in out10=2026-11-12T10:00:00Z out09=2026-11-12T09:00:00Z outb251=2026-11-06T03:23:00Z; do
  O=$D/${pair%%=*}
  W=${pair#*=}
  if [ ! -s "$O/steps.csv" ]; then
    mkdir -p "$O"
    EXTRACT_WIN_END=$W python3 -I "$X/extract.py" "$O" 2> "$O.extract.err" || exit 2
    python3 -I "$A/analyze.py" "$O" > "$O.analyze.txt" || exit 2
  fi
done
T=${EXTRACT_ROOT:-$HOME/.claude/projects/-Users-n8-git-graph}
n=0
for f in "$T"/*.jsonl; do
  [ -e "$f" ] && n=$((n + 1))
done
{
  echo "corpus: $n top-level transcripts under the graph transcript root"
  EXTRACT_WIN_END=2026-11-12T10:00:00Z BL398_OUT_B251=$D/outb251 python3 -I "$H/cost.py" "$D/out10" "$D/out09" \
    "$R/docs/analysis/pipeline-efficiency-s317-s320/b244-snapshot" "$G" ed61de745
} > "$H/cost.txt" || exit 1
python3 -I "$H/value.py" "$G" ed61de745 > "$H/value.txt" || exit 1
echo "wrote $H/cost.txt and $H/value.txt"
