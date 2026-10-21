#!/usr/bin/env bash
# BL-721 receipt. Usage: bash receipt-bl721.sh [<wait-for-deliverable.sh>] [agent|toolu]
# A plain `--dispatch <id> <path>` beat (no --complete-repair) on a path that never appears,
# at its cap (AI_DLC_MAX_WAIT_BEATS=1), the dispatch resolving to ONE agent through its
# meta.json, the subject's ledger row NOT first:
# 0 = a fresh transcript prints LIVE DISPATCH and not the bare "Re-dispatch the teammate ONCE";
#     a transcript older than IDLE_SECS prints STOPPED DISPATCH, no LIVE block, and not the bare
#     remedy; and the near-miss, the same fresh transcript with NO --dispatch, still prints the
#     bare remedy and no LIVE block (the remedy change is scoped to a resolved dispatch).
# 1 = a property failed.
# 9 = the receipt could not run.
# The second argument picks the id spelling(s) handed to --dispatch: `agent`, `toolu`, or both
# (the default); both resolve to the same agent and must give the same answers.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
SUBJ="${1:-core/scripts/wait-for-deliverable.sh}"
[ -n "${1:-}" ] || [ -f "$SUBJ" ] || SUBJ=scripts/ai-dlc/wait-for-deliverable.sh
[ -f "$SUBJ" ] || { echo "REFUSED: no subject at $SUBJ" >&2; exit 9; }
case "$SUBJ" in /*) ;; *) SUBJ="$(pwd -P)/$SUBJ" ;; esac
# --dispatch reads DISPATCH_ID_PREFIXES from this sibling; without it every call refuses.
[ -f "$(dirname "$SUBJ")/validate-adversarial-convergence.sh" ] || { echo "REFUSED: no id-grammar sibling beside $SUBJ" >&2; exit 9; }
SPELLS="${2:-agent toolu}"
TUI="toolu_01Bl721SubjectDispatchAAAA"; TUI_E="toolu_01Bl721EpochRowBBBBBBBBB"; AG="a721c8dcd555207b8"
for SPELL in $SPELLS; do case "$SPELL" in agent|toolu) ;; *) echo "REFUSED: spelling '$SPELL' is not agent|toolu" >&2; exit 9 ;; esac; done
# The bare remedy wraps after "the", so its first line is the key (run.sh's R27_REMEDY too); the
# LIVE and STOPPED blocks spell their own re-dispatch in lower case and never carry it.
REMEDY="Re-dispatch the"
LIVE="LIVE DISPATCH agent-$AG"
STOP="STOPPED DISPATCH agent-$AG"
iso() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; }
NOW="$(date +%s)"
[ -n "$(iso "$NOW")" ] || { echo "REFUSED: neither BSD nor GNU date can format an epoch" >&2; exit 9; }

world() {  # $1 = age of the transcript's last turn (s) -> W, a fresh join tree at its cap
  W="$(mktemp -d)" || exit 9
  mkdir -p "$W/.git" "$W/_bmad-output/.wait-beats" "$W/sub" || exit 9
  # The subject is NOT the first row: a one-row ledger makes its own row the answer to any lookup.
  printf '{"ts":"%s","tool_use_id":"%s","name":"","subagent_type":"architect"}\n' "$(iso $(( NOW - 400 )))" "$TUI_E" > "$W/_bmad-output/spawn-ledger.jsonl"
  printf '{"ts":"%s","tool_use_id":"%s","name":"","subagent_type":"remediator"}\n' "$(iso $(( NOW - 300 )))" "$TUI" >> "$W/_bmad-output/spawn-ledger.jsonl"
  printf '{"agentType":"remediator","toolUseId":"%s"}\n' "$TUI" > "$W/sub/agent-${AG}.meta.json"
  wt_="$(iso $(( NOW - $1 )))"; wt_="${wt_%Z}"
  { printf '{"isSidechain":true,"agentId":"%s","type":"user","message":{"role":"user"},"timestamp":"%s.100Z"}\n' "$AG" "$wt_"
    printf '{"isSidechain":true,"agentId":"%s","message":{"role":"assistant"},"type":"assistant","timestamp":"%s.300Z"}\n' "$AG" "$wt_"
  } > "$W/sub/agent-${AG}.jsonl"
  # The counters beat 1 of 1 leaves: `.bound` equal to the bound (or the bound change sweeps the
  # dir and this is a first beat), and the target's own counter at the bound.
  printf '1' > "$W/_bmad-output/.wait-beats/.bound"
  printf '1' > "$W/_bmad-output/.wait-beats/$(printf '%s' never.marker | cksum | tr -d ' \t' | cut -c1-16)"
}
run() {  # argv -> OUT, RC
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_PROJECT_ROOT="$W" AI_DLC_TEAMMATE_DIR="$W/sub" \
      AI_DLC_MAX_WAIT_BEATS=1 AI_DLC_WAIT_BEAT_SECS=30 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 \
      AI_DLC_TEAMMATE_IDLE_SECS=1200 bash "$SUBJ" "$@" ) > "$W/out" 2>&1
  RC=$?; OUT="$(cat "$W/out")"
}
has() { case "$OUT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
rc=0

for SPELL in $SPELLS; do
case "$SPELL" in agent) ID="$AG" ;; *) ID="$TUI" ;; esac
world 0; run --dispatch "$ID" never.marker
if [ "$RC" -eq 1 ] && has "NON-DELIVERY never.marker" && has "$LIVE" && ! has "$REMEDY" && ! has "PROGRESS"; then :
else echo "FAIL ($SPELL): a fresh transcript under plain --dispatch did not print LIVE DISPATCH in place of the bare remedy (rc $RC): $(printf '%s' "$OUT" | grep -E 'NON-DELIVERY|LIVE DISPATCH|Re-dispatch|PROGRESS|FAIL' | head -4)"; rc=1; fi

world 3600; run --dispatch "$ID" never.marker
if [ "$RC" -eq 1 ] && has "NON-DELIVERY never.marker" && has "$STOP" && has "agent-${AG}.jsonl" && ! has "$LIVE" && ! has "$REMEDY"; then :
else echo "FAIL ($SPELL): a transcript past IDLE_SECS under plain --dispatch did not print STOPPED in place of the bare remedy (rc $RC): $(printf '%s' "$OUT" | grep -E 'NON-DELIVERY|DISPATCH agent|Re-dispatch|FAIL' | head -4)"; rc=1; fi
done
SPELL="no --dispatch"

# NEAR-MISS: the same fresh transcript and no --dispatch is the session-wide reading, which
# decides nothing -- the bare remedy stays.
world 0; run never.marker
if [ "$RC" -eq 1 ] && has "NON-DELIVERY never.marker" && has "$REMEDY" && ! has "$LIVE" && ! has "$STOP"; then :
else echo "FAIL ($SPELL): with no --dispatch the beat lost the bare remedy or printed a dispatch block (rc $RC): $(printf '%s' "$OUT" | grep -E 'NON-DELIVERY|DISPATCH agent|Re-dispatch|FAIL' | head -4)"; rc=1; fi

[ "$rc" -eq 0 ] && echo "PASS ($SPELLS): a plain resolved --dispatch at its cap prints LIVE (fresh) or STOPPED (past IDLE_SECS), never the bare remedy; without --dispatch the bare remedy stays"
exit "$rc"
