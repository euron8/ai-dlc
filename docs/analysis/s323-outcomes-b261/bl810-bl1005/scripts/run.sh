#!/bin/bash
# b261 C7 hand: BL-810 (elicitation cross width, s323) and BL-1005 (unchanged-text shard reads, s323).
# Env: GRAPH_CLONE (file:// clone of graph; a9b015557 and da6cadadd fetched), TRANSCRIPTS (default ~/.claude/projects/-Users-n8-git-graph),
#      WORK (scratch dir), HERE (this scripts dir). EXTRACT_PY = extract.py run in place from a detached af44929cc checkout (monotone clock default), never copied here.
# Windows: s319 2026-10-14T22:00Z..2026-10-30T00:10:03Z; s321 2026-10-30T00:10:00Z..2026-11-09T00:00:00Z; s323 2026-11-13T08:00Z..2026-11-20T04:20:00Z.
set -eu
EXTRACT_PY=${EXTRACT_PY:?}; G=${GRAPH_CLONE:?}; W=${WORK:?}; H=${HERE:?}; S=${COE_SCRIPTS:?}   # S = docs/analysis/step-value-carry-over-s319-s320/scripts
mkdir -p "$W/o319" "$W/o321" "$W/o323" "$W/all" "$W/a"
git -C "$G" show a9b015557:_bmad-output/spawn-ledger.jsonl > "$W/ledger.jsonl"
EXTRACT_WIN_START=2026-10-14T22:00:00Z EXTRACT_WIN_END=2026-10-30T00:10:03Z python3 -I "$EXTRACT_PY" "$W/o319"
EXTRACT_WIN_START=2026-10-30T00:10:00Z EXTRACT_WIN_END=2026-11-09T00:00:00Z python3 -I "$EXTRACT_PY" "$W/o321"
EXTRACT_WIN_START=2026-11-13T08:00:00Z EXTRACT_WIN_END=2026-11-20T04:20:00Z python3 -I "$EXTRACT_PY" "$W/o323"
for d in o319 o321 o323; do SPAWNS_LEDGER="$W/ledger.jsonl" python3 -I "$H/spawns.py" "$W/$d"; done
cat "$W/o319/spawns.jsonl" "$W/o323/spawns.jsonl" > "$W/all/spawns.jsonl"
COE_SPRINTS=319,320,323 python3 -I "$S/cost2.py" "$W/all"
git -C "$G" archive a9b015557 _bmad-output | tar -x -C "$W/a"
A="$W/a/_bmad-output/planning-artifacts"
COE_SPRINTS=319,320,323 COE_SHIPPED_323="$A/s323/carry-over-evaluation.md" python3 -I "$S/width.py" "$W/a" "$A/s319/carry-over-evaluation.md" "$A/s320/carry-over-evaluation.md" "$W/width.json"
echo "== BL-1005 control s321"; python3 -I "$H/bl1005_unchanged.py" "$G" da6cadadd 321 "$W/o321/spawns.jsonl"
echo "== BL-1005 s323";        python3 -I "$H/bl1005_unchanged.py" "$G" a9b015557 323 "$W/o323/spawns.jsonl"
