#!/usr/bin/env bash
# updater-session-signals — the Rule 29 pause must exempt an `/ai-dlc-update` session no
# matter WHICH WAY that skill was invoked, and must exempt nothing else.
#
# THE DEFECT, filed by the reference consumer as PC-S331 and reproduced live before this
# fixture existed. `ai-dlc-acknowledge.sh` detected an updater session by grepping the
# transcript for `<command-name>/ai-dlc-update</command-name>`. That marker is written when
# the OPERATOR TYPES the slash command. When the AGENT invokes the same skill through the
# `Skill` tool it is never written -- not at the dispatch, and not anywhere later in the
# session -- so the carve-out could not fire and the first dispatch was denied every time.
# Observed twice in one live session, each time cleared by removing the pause flag and
# putting it back.
#
# THE THREE SIGNALS ARE DISJOINT, WHICH IS WHY THIS FIXTURE HAS SIX POSITIVE ARMS AND NOT
# ONE. Measured with a PreToolUse probe over two headless sessions, one per invocation path:
#
#   operator types /ai-dlc-update    the marker is present; NO `Skill` tool_use exists in
#                                    the transcript at all -- a typed slash command loads
#                                    the skill directly and calls no tool
#   agent calls Skill(ai-dlc-update)  the marker is never written; and at the dispatch the
#                                    transcript does not yet carry the tool_use line either
#                                    (12 lines, both absent). It is flushed by the time the
#                                    NEXT tool call runs (17 lines, present)
#
# So: the payload answers for the dispatch and for nothing else, the transcript's tool_use
# line answers for every call AFTER the dispatch, and the marker answers for a typed
# session. Remove any one arm and a real invocation path goes back to being denied -- which
# is what the sibling `-mutants` battery asserts one arm at a time.
#
# THE DIRECTION THAT MATTERS. A carve-out that leaks is worse than one that misfires: it
# turns the Rule 29 pause off for a pipeline session, and the pause exists because the lead
# will otherwise execute straight through a waiting human. Arms 4-8 are the load-bearing
# half. Arm 8 in particular holds the new transcript pattern to being STRUCTURAL: a session
# that merely quotes the string carries it JSON-escaped, and an escaped mention must not
# read as an invocation.
set -uo pipefail

# AI_DLC_USS_HOOK is the seam the sibling mutation battery drives; unset in every real run.
#
# READ BEFORE THE SCRUB, AND THAT ORDER IS THE WHOLE POINT. The hermetic scrub below unsets
# every AI_DLC_* variable, this one included — so a battery that exported it would find the
# real hook, every mutant would report zero reds, and each would score a SURVIVAL. Measured:
# written the other way round, all five mutants came back 0-of-0 green.
HOOK="${AI_DLC_USS_HOOK:-}"

# HERMETIC — scrub the operator's tuning before invoking any hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
[ -n "$HOOK" ] || HOOK="$(pick "$HERE/../../hooks/ai-dlc-acknowledge.sh" \
                               "$HERE/../../../.claude/hooks/ai-dlc-acknowledge.sh" \
                               "$HERE/../../../core/hooks/ai-dlc-acknowledge.sh")"
[ -n "$HOOK" ] && [ -f "$HOOK" ] \
  || { echo "FIXTURE ERROR: cannot locate ai-dlc-acknowledge.sh" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# A PAUSED project with a live pipeline and no adversarial series: the tree that reaches
# Check 3, which is the check under test. The sprint resolves and its slot exists, so
# Check 2a finds no series and logs nothing -- an UNADJUDICABLE line here would mean this
# fixture is exercising the divergence guard instead of the pause guard.
seed() {
  local w="$WORK/$1"; shift
  mkdir -p "$w/_bmad-output/planning-artifacts/s7" "$w/scripts/ai-dlc"
  : > "$w/_bmad-output/pipeline-snapshot.md"
  : > "$w/_bmad-output/pipeline-paused.flag"
  printf '#!/bin/sh\necho 7\n' > "$w/scripts/ai-dlc/sprint-status.sh"
  chmod +x "$w/scripts/ai-dlc/sprint-status.sh"
  printf '%s' "$w"
}

# Transcript bodies. Each is what the harness has actually written by the moment the hook
# runs for the call being simulated -- the ordering the live probe measured, not a guess.
TR_TYPED="$WORK/typed.jsonl"          # operator typed /ai-dlc-update
TR_AGENT_PRE="$WORK/agent-pre.jsonl"  # agent is dispatching Skill(ai-dlc-update): nothing yet
TR_AGENT_POST="$WORK/agent-post.jsonl" # ...the call after it: the tool_use line is flushed
TR_PIPELINE="$WORK/pipeline.jsonl"    # operator typed /ai-dlc
TR_RESUMED="$WORK/resumed.jsonl"      # updater tool_use, THEN a pipeline dispatch
TR_MENTION="$WORK/mention.jsonl"      # a session that only QUOTES the tool_use string

printf '{"type":"user","message":{"content":"<command-name>/ai-dlc-update</command-name>"}}\n' > "$TR_TYPED"
printf '{"type":"user","message":{"content":"take the pull"}}\n' > "$TR_AGENT_PRE"
cp "$TR_AGENT_PRE" "$TR_AGENT_POST"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"ai-dlc-update"},"caller":{"type":"direct"}}]}}\n' >> "$TR_AGENT_POST"
printf '{"type":"user","message":{"content":"<command-name>/ai-dlc</command-name>"}}\n' > "$TR_PIPELINE"
cp "$TR_AGENT_POST" "$TR_RESUMED"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"ai-dlc","args":"resume"}}]}}\n' >> "$TR_RESUMED"
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"the hook greps for \\"name\\":\\"Skill\\",\\"input\\":{\\"skill\\":\\"ai-dlc-update\\" in the transcript"}]}}\n' > "$TR_MENTION"

# Drive the PreToolUse hook. `skill` is present only on a Skill payload, exactly as the
# harness sends it -- every other tool carries no such field.
drive() { # <work> <tool> <transcript> [skill] -> stdout
  local w="$1" tool="$2" tr="$3" skill="${4:-}"
  local ti
  if [ -n "$skill" ]; then ti="$(jq -nc --arg s "$skill" '{skill:$s}')"
  else ti="$(jq -nc '{}')"; fi
  jq -nc --arg t "$tool" --arg tr "$tr" --argjson ti "$ti" \
     '{session_id:"t",transcript_path:$tr,tool_name:$t,tool_input:$ti}' \
    | CLAUDE_PROJECT_DIR="$w" bash "$HOOK" 2>/dev/null
}
denied() { case "$1" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) return 0 ;; esac; return 1; }

echo "updater-session-signals:"

# =============================================================================
# 0. THE CONTROL — the guard has teeth at all.
# =============================================================================
# Without this every "ALLOWED" below is satisfied by a hook that allows everything, which
# is precisely the hook a leaking carve-out produces. Run it first and read it as the
# fixture's own sanity arm.
W="$(seed teeth)"
OUT="$(drive "$W" Agent "$TR_PIPELINE")"
if denied "$OUT"; then ok "CONTROL: a pipeline session's Agent dispatch is DENIED while paused"
else bad "FIXTURE BROKEN: nothing is denied while paused, so every ALLOW arm below proves nothing"; fi

# =============================================================================
# 1-3. THE THREE INVOCATION PATHS — each must reach the carve-out.
# =============================================================================
OUT="$(drive "$W" Agent "$TR_TYPED")"
if denied "$OUT"; then bad "TYPED: an /ai-dlc-update session typed by the operator was DENIED"
else ok "TYPED: the operator's typed /ai-dlc-update session dispatches (the marker arm)"; fi

# The defect itself. At this instant the transcript holds NEITHER signal: the marker is
# never coming, and the tool_use line for this very call has not been flushed yet. The
# payload is the only thing that can answer, and before the fix nothing read it.
OUT="$(drive "$W" Skill "$TR_AGENT_PRE" ai-dlc-update)"
if denied "$OUT"; then bad "AGENT DISPATCH: Skill(ai-dlc-update) was DENIED — PC-S331 is back, and it denies the FIRST dispatch of every agent-driven update"
else ok "AGENT DISPATCH: Skill(ai-dlc-update) dispatches on the payload alone (nothing is in the transcript yet)"; fi

# ...and the half a payload arm cannot cover. The updater's design is a fan-out -- "dispatch
# ONE generic agent per file" -- and an Agent payload carries no skill field, so without the
# tool_use arm every one of those is denied and the model routes around it by working inline.
OUT="$(drive "$W" Agent "$TR_AGENT_POST")"
if denied "$OUT"; then bad "AGENT FAN-OUT: the updater's per-file Agent dispatch was DENIED — the carve-out covers only its own first call"
else ok "AGENT FAN-OUT: a later Agent dispatch reads the flushed tool_use line (the transcript arm)"; fi

# =============================================================================
# 4-8. THE CARVE-OUT MUST NOT LEAK.
# =============================================================================
OUT="$(drive "$W" Skill "$TR_PIPELINE" ai-dlc)"
if denied "$OUT"; then ok "NEGATIVE: an agent-driven Skill(ai-dlc) dispatch is still DENIED (the payload arm reads the skill NAME, not the field)"
else bad "the payload arm exempts ANY Skill call — the pause is off for the pipeline skill it exists to stop"; fi

# Recency in the direction that ends a pause: the transcript's last word is the updater, but
# THIS call is the pipeline resuming. The payload is newer than the transcript by
# construction, so it must win.
OUT="$(drive "$W" Skill "$TR_AGENT_POST" ai-dlc)"
if denied "$OUT"; then ok "RECENCY: a fresh Skill(ai-dlc) overrides an updater tool_use earlier in the same session"
else bad "a session that ran the updater stays exempt forever — /ai-dlc resume never re-arms the pause"; fi

# ...and the same rule read off the transcript alone, for the call after that resume.
OUT="$(drive "$W" Agent "$TR_RESUMED")"
if denied "$OUT"; then ok "RECENCY: the LAST skill in the transcript wins, not the first one found"
else bad "the transcript scan is order-blind: an updater call anywhere in the session exempts the rest of it"; fi

# THE FALSE-POSITIVE CONTROL FOR THE NEW PATTERN. A transcript that discusses the hook
# carries the string inside a JSON string, where every quote is backslash-escaped. Measured
# over 498 local transcripts, the structural form matched exactly the 69 carrying a real
# Skill(ai-dlc*) tool_use and 0 others; this arm is that measurement made permanent.
OUT="$(drive "$W" Agent "$TR_MENTION")"
if denied "$OUT"; then ok "MENTION: a transcript that only QUOTES the tool_use string is not an invocation"
else bad "an escaped MENTION reads as an invocation — any session discussing this hook turns the pause off"; fi

# A missing transcript must not exempt anything either: it is the absence of a signal, not
# an updater signal. The pre-fix hook got this right and a payload arm applied unguarded
# would not have.
OUT="$(drive "$W" Agent "$WORK/does-not-exist.jsonl")"
if denied "$OUT"; then ok "an unreadable transcript denies (absence of evidence is not the updater)"
else bad "a missing transcript exempts the session — every hook failure becomes a pause bypass"; fi

# =============================================================================
# 9. AND CHECK 2a MUST NOT HAVE BEEN WHAT ANSWERED. If the seed tripped the
#    divergence guard's unadjudicable path, the arms above read the wrong check.
# =============================================================================
if grep -q 'ADVERSARIAL_STATE_UNADJUDICABLE' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  bad "FIXTURE BROKEN: the seed is unadjudicable to Check 2a, so these arms exercised the divergence guard"
else
  ok "the seed reaches Check 3: no UNADJUDICABLE line, so the pause carve-out is what answered"
fi

echo
if [ "$fails" -eq 0 ]; then echo "updater-session-signals: PASS"; exit 0; fi
echo "updater-session-signals: $fails assertion(s) FAILED" >&2
exit 1
