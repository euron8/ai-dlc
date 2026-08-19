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

# A dispatch whose FIRST USER RECORD carries injected core prose naming
# `team-roles/adversary.md` AHEAD of the real binding. This is the measured shape
# of the role-misderivation defect: 478 of the reference consumer's 997 rows read
# `adversary` because the prose read took the first match it saw, and injected
# `<system-reminder>` context arrives inside the very record the prompt lives in.
# The prose read alone CANNOT win here — which is the point. `spawn-ledger.jsonl`,
# written at dispatch by ai-dlc-dispatch-guard.sh, is what settles it.
{
  jq -nc '{type:"user", timestamp:"2026-07-25T12:00:00.000Z",
           message:{role:"user", content:[
             {type:"text", text:"<system-reminder>The METHOD is .claude/team-roles/adversary.md</system-reminder>"},
             {type:"text", text:"First read .claude/team-roles/protected-path-editor.md and honour it as your role contract."}]}}'
  jq -nc '{type:"assistant", timestamp:"2026-07-25T12:15:00.000Z",
           message:{model:"claude-sonnet-5",
                    usage:{input_tokens:1000, cache_creation_input_tokens:0, cache_read_input_tokens:40000}}}'
} > "$WORK/polluted.jsonl"

# THE SUM, NOT ONE TERM. `mkrec` hard-wires cache_creation_input_tokens to 0 and every
# hand-written record above does the same, so the peak expression could drop that term
# entirely and every assertion would still read correctly. Here all three components are
# non-zero AND no two subsets share a total -- 1000+150000+100000 = 251000, against
# 101000 without cache_creation, 151000 without cache_read, 250000 without input_tokens
# -- so the failure message names which term went missing rather than just "wrong".
jq -nc '{type:"assistant", message:{model:"claude-opus-4-8",
         usage:{input_tokens:1000, cache_creation_input_tokens:150000,
                cache_read_input_tokens:100000}}}' > "$WORK/cachecreate.jsonl"

# A teammate whose LAST MEGABYTE holds no complete record. The hook escalates its tail
# window 1MB -> 4MB -> 16MB for exactly this shape, and no other seed here is within
# three orders of magnitude of the first window (the largest is ~540 bytes), so the
# escalation has never once run under this fixture. One 1.2MB trailing line puts the
# whole default window inside a single unparseable fragment. Without the escalation the
# teammate produces NO ROW AT ALL -- not a wrong number, an absence indistinguishable
# from a teammate that was never dispatched.
#
# The padding is built by doubling a shell string rather than with `head -c /dev/zero |
# tr '\0' X`: BSD and GNU `tr` disagree on the NUL escape, and a padding generator that
# silently emits nothing would shrink the seed below the window and quietly disarm this.
#
# THE PADDING DOES NOT GO THROUGH argv, AND THAT IS NOT A STYLE CHOICE. `jq -nc --arg p
# "$_pad"` dies with `Argument list too long` at this size -- argv is capped by ARG_MAX
# -- and because this script sets `pipefail` but not `-e`, the failure printed to a
# stderr nobody reads and the seed carried on. The result was a 153-BYTE hugetail.jsonl:
# the arm asserting the escalation was asserting the ordinary path, and it passed. Only
# the mutant that deletes the escalation exposed it. `printf` is a bash builtin, so it
# never execs and ARG_MAX does not apply; the payload is a fixed alphabet, so nothing
# here needs quoting.
_pad=XXXXXXXXXXXXXXXX
while [ ${#_pad} -lt 1200000 ]; do _pad="$_pad$_pad"; done
_pad="${_pad:0:1200000}"
{ mkrec 1000 76000
  printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$_pad"
} > "$WORK/hugetail.jsonl"
# A SEED THAT DOES NOT EXCEED THE WINDOW DISARMS ITS ARM SILENTLY. Fail loudly here
# rather than let the fixture report `ok` for a file the first read already swallowed.
_ht="$(wc -c < "$WORK/hugetail.jsonl" | tr -d ' ')"
if [ "${_ht:-0}" -le 1048576 ]; then
  echo "FIXTURE ERROR: hugetail.jsonl is ${_ht} bytes, which the default 1048576 tail window swallows whole -- the escalation arm cannot fire" >&2
  exit 2
fi

# ROLE PROSE AHEAD OF THE DISPATCH PROMPT, in a record the lead did not author.
# `polluted.jsonl` puts the poison INSIDE the first user record, which is the half the
# scoping cannot filter and which 8a asserts still wins; this puts it in an earlier
# NON-user record, which is the half the scoping exists for. Read unscoped, the first
# match wins and the answer is `adversary`. Read scoped to the dispatch prompt, the
# `qa` binding wins. No other seed separates those two readings.
{ jq -nc '{type:"system", timestamp:"2026-07-26T09:00:00.000Z",
           content:"injected context: the METHOD is .claude/team-roles/adversary.md"}'
  jq -nc '{type:"user", timestamp:"2026-07-26T09:00:01.000Z",
           message:{role:"user", content:"READ AND FOLLOW .claude/team-roles/qa.md"}}'
  jq -nc '{type:"assistant", timestamp:"2026-07-26T09:20:00.000Z",
           message:{model:"claude-opus-4-8",
                    usage:{input_tokens:1000, cache_creation_input_tokens:0,
                           cache_read_input_tokens:52000}}}'
} > "$WORK/prefixrole.jsonl"

# TWO ASSISTANT ARMS, TWO DIFFERENT MODELS. Every other seed is single-model or uniform,
# so `last` and `first` return the same string and the field's direction is unasserted.
# A teammate that escalated mid-run ends on the model it finished as, and that is the
# one the row must carry.
{ mkrec 1000 10000 claude-sonnet-5
  mkrec 1000 33000 claude-opus-4-8
} > "$WORK/multimodel.jsonl"

# RECORDS OUT OF CHRONOLOGICAL ORDER, so end_ts precedes start_ts. A negative duration
# must never reach the row: it is not a reading, and it would sum into every total taken
# over this file. Two guards in the hook stand between this seed and a row, and they are
# redundant with each other -- this seed gives the PAIR a subject, which neither had.
{ jq -nc '{type:"user", timestamp:"2026-07-27T10:00:00.000Z",
           message:{role:"user", content:"go"}}'
  jq -nc '{type:"assistant", timestamp:"2026-07-27T08:00:00.000Z",
           message:{model:"claude-opus-4-8",
                    usage:{input_tokens:1000, cache_creation_input_tokens:0,
                           cache_read_input_tokens:63000}}}'
} > "$WORK/backwards.jsonl"

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
PROJ="$PROJ"
NOPIPE="$NOPIPE"
WORKDIR="$WORK"
ENV

printf '%s\n' "$WORK"
