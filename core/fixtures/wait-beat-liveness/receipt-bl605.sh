#!/usr/bin/env bash
# BL-605 receipt (row side). Usage: bash receipt-bl605.sh [<wait-for-deliverable.sh>]
# 0 = `--dispatch-ts <id>` prints the dispatch's spawn-ledger ts VERBATIM (via the agentId's
#     meta.json AND via the toolu_ id), that stamp differs from a row hand-stamped 57 s late
#     (the motivating row), a second ledger row resolves to ITS OWN ts, an id with no ledger row
#     is refused with dispatch_refuse's text, and the call writes no lease.
# 1 = a property failed (a subject without the flag fails here: no stamp printed).
# 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
SUBJ="${1:-core/scripts/wait-for-deliverable.sh}"
[ -n "${1:-}" ] || [ -f "$SUBJ" ] || SUBJ=scripts/ai-dlc/wait-for-deliverable.sh
[ -f "$SUBJ" ] || { echo "REFUSED: no subject at $SUBJ" >&2; exit 9; }
case "$SUBJ" in /*) ;; *) SUBJ="$(pwd -P)/$SUBJ" ;; esac
# --dispatch reads DISPATCH_ID_PREFIXES from this sibling; without it every call refuses.
[ -f "$(dirname "$SUBJ")/validate-adversarial-convergence.sh" ] || { echo "REFUSED: no id-grammar sibling beside $SUBJ" >&2; exit 9; }
W="$(mktemp -d)" || exit 9
mkdir -p "$W/.git" "$W/_bmad-output" "$W/sub"
# The motivating pair (BL-605): dispatched 05:00:03Z, row stamped 05:01:00Z.
D="2026-10-16T05:00:03Z"; LATE="2026-10-16T05:01:00Z"
E="2026-10-16T04:58:41Z"
TUI="toolu_01Bl605SubjectDispatchAAAA"; TUI_E="toolu_01Bl605EpochRowBBBBBBBBB"; AG="a7ffc8dcd555207b8"
# The subject is NOT the first row: a one-row ledger makes its own row the answer to any lookup.
printf '{"ts":"%s","tool_use_id":"%s","name":"","subagent_type":"architect"}\n' "$E" "$TUI_E" > "$W/_bmad-output/spawn-ledger.jsonl"
printf '{"ts":"%s","tool_use_id":"%s","name":"","subagent_type":"remediator"}\n' "$D" "$TUI" >> "$W/_bmad-output/spawn-ledger.jsonl"
printf '{"agentType":"remediator","toolUseId":"%s"}\n' "$TUI" > "$W/sub/agent-${AG}.meta.json"
stamp() {  # $1 = id -> OUT, ERR, SRC
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_PROJECT_ROOT="$W" AI_DLC_TEAMMATE_DIR="$W/sub" \
      bash "$SUBJ" --dispatch-ts "$1" ) > "$W/out" 2> "$W/err"
  SRC=$?; OUT="$(cat "$W/out")"; ERR="$(cat "$W/err")"
}
rc=0
stamp "$AG"
if [ "$SRC" -ne 0 ]; then
  echo "FAIL: no stamp printed for agentId $AG (rc $SRC: $(printf '%s' "$ERR" | head -1))"; rc=1
else
  [ "$OUT" = "$D" ] || { echo "FAIL: agentId stamp '$OUT' is not the ledger ts $D"; rc=1; }
  [ "$OUT" != "$LATE" ] || { echo "FAIL: the stamp equals the 57 s late hand stamp $LATE"; rc=1; }
fi
stamp "$TUI"
[ "$SRC" -eq 0 ] && [ "$OUT" = "$D" ] || { echo "FAIL: toolu_ stamp '$OUT' (rc $SRC) is not $D"; rc=1; }
stamp "$TUI_E"
[ "$SRC" -eq 0 ] && [ "$OUT" = "$E" ] || { echo "FAIL: the other row's stamp '$OUT' (rc $SRC) is not its own ts $E -- the lookup does not discriminate"; rc=1; }
stamp "toolu_01Bl605NoSuchDispatchZZZ"
if [ "$SRC" -eq 0 ] || [ -n "$OUT" ]; then
  echo "FAIL: an id with no ledger row printed '$OUT' (rc $SRC) instead of refusing"; rc=1
else
  case "$ERR" in *"FAIL: --dispatch"*"0 row(s)"*) : ;;
    *) echo "FAIL: an id with no ledger row was not refused by name (rc $SRC: $(printf '%s' "$ERR" | head -1))"; rc=1 ;; esac
fi
[ -e "$W/_bmad-output/.beat-inflight" ] && { echo "FAIL: --dispatch-ts wrote the beat lease"; rc=1; }
[ -e "$W/_bmad-output/.wait-beats" ] && { echo "FAIL: --dispatch-ts created the state dir's .wait-beats"; rc=1; }
[ "$rc" -eq 0 ] && echo "PASS: dispatched-at is the ledger ts ($D, not the late $LATE), per row, and a missing row is refused"
exit "$rc"
