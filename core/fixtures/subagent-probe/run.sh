#!/usr/bin/env bash
#
# Drives ai-dlc-subagent-probe.sh (SubagentStop). Exits non-zero on any failure.
set -uo pipefail

# The pre-push gate exports every AI_DLC_* tunable a consumer set in settings.json into this
# process. Scrub them so the hook is tested against its own defaults, not the tester's env.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
chk() { [ "$2" = "$3" ] && ok "$1" || bad "$1 -- expected '$3', got '$2'"; }

OUT="$PROJ/_bmad-output/subagent-context.jsonl"

# fire <project> <transcript> [agent_id]
fire() {
  jq -nc --arg t "$WORKDIR/$2" --arg a "${3:-adversary-s291-p1}" \
    '{transcript_path:$t, agent_id:$a, hook_event_name:"SubagentStop"}' \
    | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null
}
last() { tail -1 "$OUT" 2>/dev/null | jq -r "$1 // empty" 2>/dev/null; }
reset() { rm -f "$OUT"; }

echo "subagent-probe"

# --- 1. NEVER BLOCKS. SubagentStop can block a subagent from stopping; this hook
#        must never emit anything on stdout or exit non-zero.
reset
OUTPUT="$(fire "$PROJ" calm.jsonl)"; rc=$?
chk "emits nothing on stdout (a blocking SubagentStop hook would hang a teammate)" "${OUTPUT:-<empty>}" "<empty>"
chk "  exits 0" "$rc" "0"

# --- 2. records a calm teammate's peak ---------------------------------------
chk "records peak_tokens" "$(last .peak_tokens)" "60000"
chk "  records the teammate's model" "$(last .model)" "claude-opus-4-8"
chk "  records the sprint from the snapshot" "$(last .sprint)" "291"
chk "  records agent_id" "$(last .agent_id)" "adversary-s291-p1"
chk "  schema-stamped" "$(last .v)" "1"
chk "  no compaction seen" "$(last .compactions)" "0"

# --- 3. THE MEASUREMENT THAT MATTERS: a teammate that crowded the ceiling -----
# 265000 against a 287000 threshold. This is the reading that would justify
# raising autoCompactWindow — if the probe under-reports it, the ceiling decision
# is made on a number that says teammates are safe when they are not.
reset
fire "$PROJ" crowded.jsonl >/dev/null
chk "reports the PEAK, not the final reading (teammate crowding the ceiling)" "$(last .peak_tokens)" "265000"

# --- 4. THE SMOKING GUN: a teammate that actually compacted ------------------
# The peak must survive the boundary. A probe that reports only post-compaction
# usage would say 41000 — calm — for a teammate that just lost half its context
# with no recovery wiring. That reading would be worse than no reading.
reset
fire "$PROJ" compacted.jsonl >/dev/null
chk "detects a teammate compaction" "$(last .compactions)" "1"
chk "  peak survives the compact_boundary (pre-compaction peak, not post)" "$(last .peak_tokens)" "286000"

# --- 4b. THE STALL SIGNAL: long wall-clock, almost no turns ------------------
# peak_tokens reports 45000 here — calm — for a teammate that produced two turns
# in two hours. Duration is the only field that sees it, and duration alone is
# not enough either: a healthy long run turns steadily. Assert BOTH, and assert
# the ratio, because that pair is what a bound would eventually be argued from.
reset
fire "$PROJ" stalled.jsonl >/dev/null
chk "records duration_s (the field peak_tokens cannot substitute for)" "$(last .duration_s)" "7200"
chk "  records the Rule 19 role binding from the dispatch prompt" "$(last .role)" "dev"
chk "  peak still reads CALM, which is why duration is not redundant" "$(last .peak_tokens)" "45000"
chk "  turns-per-hour is the discriminator, not duration alone" "$(last .turns)" "2"

# A field that is ALWAYS null looks exactly like a field with nothing to report.
# These two prove the null is a reading, not the only thing the code can emit.
reset
fire "$PROJ" calm.jsonl >/dev/null
chk "duration_s is null when the transcript carries no timestamps (not 0)" "$(last .duration_s)" ""
chk "  role is null when no binding was dispatched (not empty-string)" "$(last .role)" ""

# --- 5. silence cases --------------------------------------------------------
reset
fire "$PROJ" nousage.jsonl >/dev/null
chk "transcript with no usage writes nothing" "$([ -f "$OUT" ] && echo present || echo absent)" "absent"

reset
fire "$PROJ" does-not-exist.jsonl >/dev/null
chk "unreadable transcript writes nothing (fail-open)" "$([ -f "$OUT" ] && echo present || echo absent)" "absent"

# --- 6. activation gate: no pipeline -> total no-op --------------------------
rm -f "$NOPIPE/_bmad-output/subagent-context.jsonl"
fire "$NOPIPE" calm.jsonl >/dev/null
chk "no pipeline snapshot → no-op" \
  "$([ -f "$NOPIPE/_bmad-output/subagent-context.jsonl" ] && echo present || echo absent)" "absent"

# --- 7. append-only: two teammates, two rows --------------------------------
reset
fire "$PROJ" calm.jsonl adversary-s291-p1 >/dev/null
fire "$PROJ" crowded.jsonl gate-adjudicator-s291-story >/dev/null
chk "appends one row per teammate (never truncates)" "$(wc -l < "$OUT" | tr -d ' ')" "2"
chk "  and keeps them distinct" "$(last .agent_id)" "gate-adjudicator-s291-story"

echo
if [ "$fails" -eq 0 ]; then echo "subagent-probe: PASS"; exit 0; fi
echo "subagent-probe: $fails assertion(s) FAILED" >&2
exit 1
