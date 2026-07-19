#!/usr/bin/env bash
#
# Seeds a throwaway pipeline tree + synthetic teammate transcripts for the
# subagent-probe fixture. Prints WORK on stdout; writes $WORK/env.sh.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# core/fixtures/<name>/ and tests/fixtures/<name>/ are BOTH three dirs below root.
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/hooks/ai-dlc-subagent-probe.sh" ]; then
  HOOK="$D_ROOT/core/hooks/ai-dlc-subagent-probe.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/hooks/ai-dlc-subagent-probe.sh" ]; then
  HOOK="$C_ROOT/.claude/hooks/ai-dlc-subagent-probe.sh"
else
  echo "FIXTURE ERROR: ai-dlc-subagent-probe.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"   # macOS /tmp is a symlink

PROJ="$WORK/proj"
NOPIPE="$WORK/nopipe"
mkdir -p "$PROJ/_bmad-output" "$NOPIPE/_bmad-output"
printf -- '- **sprint_id:** 291\n' > "$PROJ/_bmad-output/pipeline-snapshot.md"
# NOPIPE deliberately has no snapshot -> the probe must be a total no-op there.

# assistant <in> <cacheRead> -> one assistant record
mkrec() {
  jq -nc --argjson i "$1" --argjson cr "$2" --arg m "${3:-claude-opus-4-8}" \
    '{type:"assistant", message:{model:$m, usage:{input_tokens:$i, cache_creation_input_tokens:0, cache_read_input_tokens:$cr}}}'
}

# 1. A calm teammate: peaks at 60000, never near the 287000 threshold.
{ mkrec 1000 20000; mkrec 1000 59000; } > "$WORK/calm.jsonl"

# 2. A teammate that CROWDED the ceiling: peaks at 265000. Never compacted, but
#    it was inside the blast radius — this is the case that would justify raising
#    autoCompactWindow, and the whole reason the probe exists.
{ mkrec 1000 20000; mkrec 1000 264000; mkrec 1000 100000; } > "$WORK/crowded.jsonl"

# 3. A teammate that ACTUALLY COMPACTED — the smoking gun. Peak BEFORE the
#    boundary must still be reported: it came back down afterwards, but it spent
#    time at the ceiling and lost context with no recovery wiring.
{ mkrec 1000 20000
  mkrec 1000 285000
  jq -nc '{type:"system", subtype:"compact_boundary"}'
  mkrec 1000 40000
} > "$WORK/compacted.jsonl"

# 4. No usage anywhere -> nothing to assert, must stay silent.
jq -nc '{type:"user", message:{content:"hi"}}' > "$WORK/nousage.jsonl"

# 5. A STALLED teammate: 2 hours of wall-clock across 2 turns, nowhere near the
#    ceiling. peak_tokens calls this healthy — 45000 is calm — and that is exactly
#    the point. Duration is the only field that sees it. The reference consumer's
#    worst case was 699 minutes at 127 turns while a HEALTHY run took 151 minutes
#    at 781 turns, so neither duration nor turns alone separates them; the seed
#    carries both so the pair can be asserted.
#
#    It also carries the Rule 19 role binding in its opening prompt, because a
#    `role` that is always null makes every per-role reading of this log vacuous
#    while looking exactly like a log with nothing to report.
{ jq -nc '{type:"user", timestamp:"2026-07-19T08:00:00.000Z",
           message:{role:"user", content:"READ AND FOLLOW .claude/team-roles/dev.md then implement story 3"}}'
  jq -nc '{type:"assistant", timestamp:"2026-07-19T08:05:00.000Z",
           message:{model:"claude-opus-4-8", usage:{input_tokens:1000, cache_creation_input_tokens:0, cache_read_input_tokens:44000}}}'
  jq -nc '{type:"assistant", timestamp:"2026-07-19T10:00:00.000Z",
           message:{model:"claude-opus-4-8", usage:{input_tokens:1000, cache_creation_input_tokens:0, cache_read_input_tokens:30000}}}'
} > "$WORK/stalled.jsonl"

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
PROJ="$PROJ"
NOPIPE="$NOPIPE"
WORKDIR="$WORK"
ENV

printf '%s\n' "$WORK"
