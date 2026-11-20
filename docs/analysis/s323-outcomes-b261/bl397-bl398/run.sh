#!/bin/bash
# BL-397 and BL-398 readings on graph's COMPLETE sprint 323, batch 261 (C7). Reproduce from the repo root:
#   bash docs/analysis/s323-outcomes-b261/bl397-bl398/run.sh <scratch dir> <graph clone at a9b015557> <af44929cc archive dir>
# <af44929cc archive dir> holds `git archive af44929cc docs/analysis/pipeline-efficiency-s317-s320/scripts
# docs/analysis/pipeline-efficiency-s317-s318/scripts` extracted (the C5 monotone-clock extractor, blobs extract.py 67e7a72f7 and
# roll.py a6880f3ac). No af44929cc file is committed here; this runner and the scripts beside it are the b256 scripts retargeted to s323.
# Reads transcripts at ~/.claude/projects/-Users-n8-git-graph (read only). Writes only under <scratch dir> and this directory
# (out/, bl398/cost323.txt, bl398/prestep_bound.txt). The window ends at 2026-11-20T04:20:00Z (after the last s323 record);
# the alt window 2026-11-19T20:00:00Z is the identity control for the s323 rows.
set -u
S=$1
G=$2
C5=$3
H=$(cd "$(dirname "$0")" && pwd)
R=$H
while [ "$R" != "/" ] && ! { [ -e "$R/.git" ] && [ -f "$R/docs/backlog.md" ]; }; do R=$(dirname "$R"); done
[ "$R" != "/" ] || { echo "run.sh: no repo root above $H" >&2; exit 2; }
XD=$C5/docs/analysis/pipeline-efficiency-s317-s320/scripts
AD=$C5/docs/analysis/pipeline-efficiency-s317-s318/scripts
[ -f "$XD/extract.py" ] && [ -f "$XD/roll.py" ] && [ -f "$AD/analyze.py" ] || { echo "run.sh: $C5 lacks the extractor scripts" >&2; exit 2; }
export AI_DLC_XDIR=$XD
T=$HOME/.claude/projects/-Users-n8-git-graph
REF=a9b015557
IA=_bmad-output/implementation-artifacts
mkdir -p "$H/out"
for pair in c5main=2026-11-20T04:20:00Z c5alt=2026-11-19T20:00:00Z; do
  O=$S/${pair%%=*}
  if [ ! -s "$O/steps.csv" ]; then
    EXTRACT_WIN_END=${pair#*=} python3 -I "$XD/extract.py" "$O" > "$O.log" 2> "$O.err" || exit 2
    python3 -I "$AD/analyze.py" "$O" > "$O.analyze.txt" || exit 2
  fi
done
NOTE="extract.py/roll.py = af44929cc (C5 monotone clock default; blobs extract.py 67e7a72f7, roll.py a6880f3ac); EXTRACT_WIN_END main 2026-11-20T04:20:00Z, alt 2026-11-19T20:00:00Z; graph ref $REF"
# git-based readings, at the close sha 16fd227d9 and at a9b015557 (the answer to whether the last close commit moved any number)
for X in 16fd227d9 $REF; do
  {
    echo "# python3 -I bl397/story_count.py <graph clone> $X 323=... 322=... 321=...   then precondition_rejects.py, handoff_runs.py at $X"
    python3 -I "$H/bl397/story_count.py" "$G" $X 323=$IA/sprint-status.yaml 322=$IA/s322/sprint-status.yaml 321=$IA/s321/sprint-status.yaml; echo "exit $?"
    python3 -I "$H/bl397/precondition_rejects.py" "$G" $X 315 317 318 319 320 321 322 323; echo "exit $?"
    python3 -I "$H/bl397/handoff_runs.py" "$G" $X; echo "exit $?"
  } > "$H/out/git_reads.$X.txt" 2>&1
done
{ echo "# $NOTE"; python3 -I "$H/bl397/cost_rows.py" "$S/c5main" "$S/c5alt"; echo "exit $?"; } > "$H/out/cost_rows.txt" 2>&1
{ echo "# $NOTE"; EXTRACT_WIN_END=2026-11-20T04:20:00Z python3 -I "$H/bl397/gate_span_exposure.py" "$T" "$S/c5main"; echo "exit $?"; } > "$H/out/gate_span_exposure.txt" 2>&1
{ echo "# $NOTE"; GRAPH_REF=$REF python3 -I "$H/bl397/value_observable.py" "$G" "$S/c5main"; echo "exit $?"; } > "$H/out/value_observable.txt" 2>&1
{ echo "# $NOTE"; python3 -I "$H/bl398/cost.py" "$S/c5main" "$S/c5alt" "$R/docs/analysis/pipeline-efficiency-s317-s320/b244-snapshot" "$G" $REF; echo "exit $?"; } > "$H/bl398/cost323.txt" 2>&1
{ echo "# $NOTE"; python3 -I "$H/bl398/prestep_bound.py" "$R/docs/analysis/pipeline-efficiency-s317-s320/b244-snapshot"; } > "$H/bl398/prestep_bound.txt" 2>&1
{ echo "# $NOTE"; python3 -I "$H/ledger_join.py" "$G" "$S/c5main"; } > "$H/out/ledger_join.txt" 2>&1
echo "wrote $H/out/*.txt, $H/bl398/cost323.txt, $H/bl398/prestep_bound.txt"
