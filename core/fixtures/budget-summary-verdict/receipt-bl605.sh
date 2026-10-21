#!/usr/bin/env bash
# BL-605 receipt (gate side). Usage: bash receipt-bl605.sh [<validate-artifact-budget.sh>] [deco|toolu]
# Drives the GATE scan over a seeded world and reads its verdict.
# 0 = the subject row is LATE, by its one resolving id, with its dispatch's ledger ts: the motivating
#     decorated cell (`deco`, the default) or its toolu_ spelling (`toolu`). A row 1 s EARLY is LATE
#     too, an equal row is quiet, and the gate exits 1. With every row rewritten to its ledger ts the
#     gate exits 0 with no LATE line.
# 1 = a property failed (a validator with no LATE arm, or a later-than predicate, fails here).
# 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_CODE_SESSION_ID
SUBJ="${1:-core/scripts/validate-artifact-budget.sh}"
[ -n "${1:-}" ] || [ -f "$SUBJ" ] || SUBJ=scripts/ai-dlc/validate-artifact-budget.sh
[ -f "$SUBJ" ] || { echo "REFUSED: no subject at $SUBJ" >&2; exit 9; }
case "$SUBJ" in /*) ;; *) SUBJ="$(pwd -P)/$SUBJ" ;; esac
for s in wait-for-deliverable.sh validate-adversarial-convergence.sh; do
  [ -f "$(dirname "$SUBJ")/$s" ] || { echo "REFUSED: no $s beside $SUBJ" >&2; exit 9; }
done
case "${2:-deco}" in
  deco)  CELL='remediator (serial, pass 1 cross-part, a7ffc8dcd555207b8)'; ID=a7ffc8dcd555207b8 ;;
  toolu) CELL='toolu_01Bl605GateSubjectAAAAA'; ID=toolu_01Bl605GateSubjectAAAAA ;;
  *) echo "REFUSED: spelling is deco or toolu" >&2; exit 9 ;;
esac
W="$(mktemp -d)" || exit 9
mkdir -p "$W/.claude" "$W/_bmad-output" "$W/sub" || exit 9
printf 'tiny\n' > "$W/_bmad-output/gate-log.md"
# The subject is NOT the first ledger row; the producer's compact shape.
printf '%s\n' '{"ts":"2026-10-16T04:58:41Z","name":"","role":"architect","tool_use_id":"toolu_01Bl605GateEpochBBBBBBB"}' \
  '{"ts":"2026-10-16T05:00:03Z","name":"","role":"remediator","tool_use_id":"toolu_01Bl605GateSubjectAAAAA"}' \
  '{"ts":"2026-10-16T05:10:20Z","name":"","role":"dev","tool_use_id":"toolu_01Bl605GateEarlyCCCCCCC"}' \
  > "$W/_bmad-output/spawn-ledger.jsonl"
printf '{"agentType":"remediator","toolUseId":"toolu_01Bl605GateSubjectAAAAA"}\n' > "$W/sub/agent-a7ffc8dcd555207b8.meta.json"
printf '{"agentType":"dev","toolUseId":"toolu_01Bl605GateEarlyCCCCCCC"}\n' > "$W/sub/agent-a2222222222222222.meta.json"
snap() { # snap <subject stamp> <early-row stamp>
  printf '## Pipeline Position\n- at gate\n## Sprint Context\n- s1\n## Recent Activity\n- nothing\n## Open Items\n- none\n## Locked Decisions\n- none\n## In-Flight Teammates\nagent | role | deliverable | dispatched-at | status\n--- | --- | --- | --- | ---\n%s | remediator | r1 | %s | in-flight\na2222222222222222 | dev | d1 | %s | in-flight\n## Context Reminders\n- none\n' \
    "$CELL" "$1" "$2" > "$W/_bmad-output/pipeline-snapshot.md"
}
gate() { AI_DLC_SNAPSHOT_NOW_EPOCH=1792137600 AI_DLC_TEAMMATE_DIR="$W/sub" \
  bash "$SUBJ" --root "$W" --only pipeline-snapshot.md > "$W/out" 2>&1; }
snap 2026-10-16T05:01:00Z 2026-10-16T05:10:19Z
gate; rc=$?
[ "$rc" = 1 ] || { echo "FAIL: the gate exited $rc over a 57 s late row and a 1 s early one (want 1)" >&2; exit 1; }
grep -qxF "LATE  _bmad-output/pipeline-snapshot.md line 14: $ID dispatched-at 2026-10-16T05:01:00Z is not its dispatch's ledger ts 2026-10-16T05:00:03Z" "$W/out" \
  || { echo "FAIL: no LATE line for the subject row naming $ID and 05:00:03Z" >&2; exit 1; }
grep -qxF "LATE  _bmad-output/pipeline-snapshot.md line 15: a2222222222222222 dispatched-at 2026-10-16T05:10:19Z is not its dispatch's ledger ts 2026-10-16T05:10:20Z" "$W/out" \
  || { echo "FAIL: the row 1 s EARLY is not LATE (a later-than predicate)" >&2; exit 1; }
snap 2026-10-16T05:00:03Z 2026-10-16T05:10:20Z
gate; rc=$?
[ "$rc" = 0 ] || { echo "FAIL: the gate exited $rc with every row equal to its ledger ts (want 0)" >&2; exit 1; }
n="$(grep -c '^LATE ' "$W/out")" || n=0
[ "$n" = 0 ] || { echo "FAIL: $n LATE line(s) with every row equal to its ledger ts" >&2; exit 1; }
echo "PASS: the gate reads the $ID row LATE by its ledger ts, the 1 s early row too, and equal rows quiet"
exit 0
