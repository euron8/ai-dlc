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
# read as an invocation. The MENTION arms hold the TYPED form to the same standard, where
# JSON escaping does not help: angle brackets are not escaped, so the marker is anchored on
# the harness's whole user record instead.
#
# THE WRITE SURFACE (section W). An updater session's Edit under `_bmad-output/` passes the
# pause silently, a teammate's passes logged only in a pipeline session, and a pipeline lead's
# is denied. Since that exemption keys on the same signal, the MENTION arms are what stop it
# from becoming a pause bypass for every pipeline session that reads a file quoting the marker.
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
echo "HERMETIC-CONSUMED $(cd "$(dirname "$HOOK")" && pwd)/$(basename "$HOOK")"
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

# A TYPED SLASH COMMAND IS THE HARNESS'S WHOLE USER RECORD, not the bare `<command-name>` marker.
# Lifted from the reference consumer's transcripts: every one of 296 real typed ai-dlc invocations
# is `"role":"user","content":"<command-message>X</command-message>\n<command-name>/X</command-name>
# \n<command-args>...`. The bare marker is also what a QUOTATION of it looks like, which is the
# leak the MENTION arms below hold shut; a seed of the bare marker is a mention, not an invocation.
typed() { # <skill> -> one typed-invocation record
  printf '{"type":"user","message":{"role":"user","content":"<command-message>%s</command-message>\\n<command-name>/%s</command-name>\\n<command-args></command-args>"}}\n' "$1" "$1"
}
ROUTE_READ='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_r","name":"Read","input":{"file_path":"/w/.claude/skills/ai-dlc/steps/route.md"}}]}}'
typed ai-dlc-update > "$TR_TYPED"
printf '{"type":"user","message":{"content":"take the pull"}}\n' > "$TR_AGENT_PRE"
cp "$TR_AGENT_PRE" "$TR_AGENT_POST"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"ai-dlc-update"},"caller":{"type":"direct"}}]}}\n' >> "$TR_AGENT_POST"
typed ai-dlc > "$TR_PIPELINE"
cp "$TR_AGENT_POST" "$TR_RESUMED"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"ai-dlc","args":"resume"}}]}}\n' >> "$TR_RESUMED"
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"the hook greps for \\"name\\":\\"Skill\\",\\"input\\":{\\"skill\\":\\"ai-dlc-update\\" in the transcript"}]}}\n' > "$TR_MENTION"

# THE WRITE SURFACE's PIPELINE SESSIONS HAVE ROUTED. A lead Edit in an `/ai-dlc` session that never
# Read `steps/route.md` is denied by Check 2z before Check 3 is reached, so without the Read every
# DENY below would be Check 2z's and prove nothing about the pause. Each arm also demands the Rule
# 29 reason by value, which Check 2z's reason does not carry.
TR_PIPE_ROUTED="$WORK/pipe-routed.jsonl"
{ cat "$TR_PIPELINE"; printf '%s\n' "$ROUTE_READ"; } > "$TR_PIPE_ROUTED"
TR_RESUMED_ROUTED="$WORK/resumed-routed.jsonl"
{ cat "$TR_RESUMED"; printf '%s\n' "$ROUTE_READ"; } > "$TR_RESUMED_ROUTED"
# THE OTHER ORDER (BL-404): a routed, typed `/ai-dlc` lead that then calls Skill(ai-dlc-update).
# TR_RESUMED is the updater FIRST; this is the updater LAST, so the last-skill rule makes the
# session the updater and its pause stops binding until `/ai-dlc` is invoked again -- accepted by
# contract. The typed `/ai-dlc` record comes first, so a scan that took the FIRST skill instead of
# the last reads this session as the pipeline and denies it.
TR_PIPE_THEN_UPD="$WORK/pipe-then-upd.jsonl"
{ cat "$TR_PIPE_ROUTED"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"ai-dlc-update"},"caller":{"type":"direct"}}]}}\n'
} > "$TR_PIPE_THEN_UPD"

# THE THREE MENTIONS. Each is a routed `/ai-dlc` pipeline session whose LAST line quotes the
# updater's typed marker -- the order that makes a mention the last match, which is the only order
# in which reading it as an invocation changes anything.
#   read:  a Read of the push-candidate ledger, the marker mid-line inside the tool_result -- the
#          reference consumer's ledger carries it, and retro sends pipeline sessions to read it.
#   text:  the lead's own assistant text quoting it.
#   head:  a Bash tool_result whose output STARTS with the pair (`sed -n` landing on it). Its
#          string follows `"content":"` exactly as a typed record's does, so this is the seed that
#          separates the shipped anchor from one lacking its `"role":"user",` prefix.
TR_M_READ="$WORK/m-read.jsonl"; TR_M_TEXT="$WORK/m-text.jsonl"; TR_M_HEAD="$WORK/m-head.jsonl"
{ cat "$TR_PIPE_ROUTED"
  printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_l","type":"tool_result","content":"    22\t**Derivation.** In this session the transcript carries `<command-name>/ai-dlc-update</command-name>` (the operator typed it)"}]}}'
} > "$TR_M_READ"
{ cat "$TR_PIPE_ROUTED"
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"The ledger says the operator typed <command-message>ai-dlc-update</command-message>\n<command-name>/ai-dlc-update</command-name> in that session."}]}}'
} > "$TR_M_TEXT"
{ cat "$TR_PIPE_ROUTED"
  printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_b","type":"tool_result","content":"<command-message>ai-dlc-update</command-message>\n<command-name>/ai-dlc-update</command-name>\n<command-args></command-args>"}]}}'
} > "$TR_M_HEAD"

# Drive the PreToolUse hook. `skill` is present only on a Skill payload, exactly as the
# harness sends it -- every other tool carries no such field.
drive() { # <work> <tool> <transcript> [skill] [file_path] [agent_id] -> stdout
  local w="$1" tool="$2" tr="$3" skill="${4:-}" fp="${5:-}" ag="${6:-}"
  local ti
  if [ -n "$skill" ]; then ti="$(jq -nc --arg s "$skill" '{skill:$s}')"
  elif [ -n "$fp" ]; then ti="$(jq -nc --arg p "$fp" '{file_path:$p}')"
  else ti="$(jq -nc '{}')"; fi
  jq -nc --arg t "$tool" --arg tr "$tr" --argjson ti "$ti" --arg ag "$ag" \
     '{session_id:"t",transcript_path:$tr,tool_name:$t,tool_input:$ti}
      + (if $ag == "" then {} else {agent_id:$ag,agent_type:"general-purpose"} end)' \
    | CLAUDE_PROJECT_DIR="$w" bash "$HOOK" 2>/dev/null
}
denied() { case "$1" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) return 0 ;; esac; return 1; }
# A DENY THAT IS THE PAUSE's, by value. Check 2z denies the same tools with a different reason, and a
# write arm reading only `denied` could not tell which check answered.
paused_deny() { denied "$1" && case "$1" in *'AI/DLC Rule 29: the pipeline is PAUSED'*) return 0 ;; esac; return 1; }
# Event counts, one row per `## <ts> -- <EVENT>` line (the log header names every event, so a bare
# grep over-counts). An absent log is zero rows.
rows() { # <work> <event> -> count
  local n; n="$(grep -c "^## .*-- $2\$" "$1/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)" || n=0
  printf '%s' "$n"
}
# ONE WRITE ARM: a fresh paused tree per arm, so each log count is that arm's alone.
# -> "<ALLOW|DENY|OTHER> <ACK_DENIED rows> <ACK_TEAMMATE_WRITE rows> <File: line matches>"
wcell() { # <label> <tool> <transcript> [agent_id]
  local w fp out v f
  w="$(seed "w-$1")"; fp="$w/_bmad-output/planning-artifacts/s7/x.md"
  out="$(drive "$w" "$2" "$3" "" "$fp" "${4:-}")"
  if paused_deny "$out"; then v=DENY; elif denied "$out"; then v=OTHER; else v=ALLOW; fi
  f="$(grep -cF -- "- File: $fp" "$w/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)" || f=0
  printf '%s %s %s %s' "$v" "$(rows "$w" ACK_DENIED)" "$(rows "$w" ACK_TEAMMATE_WRITE)" "$f"
}
# The same, for a dispatch. Agent carries no file, so there is no File: line to count.
acell() { # <label> <transcript>
  local w out
  w="$(seed "a-$1")"
  out="$(drive "$w" Agent "$2")"
  if paused_deny "$out"; then printf 'DENY %s' "$(rows "$w" ACK_DENIED)"
  elif denied "$out"; then printf 'OTHER %s' "$(rows "$w" ACK_DENIED)"
  else printf 'ALLOW %s' "$(rows "$w" ACK_DENIED)"; fi
}

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
# W. THE WRITE SURFACE — an updater session's Edit under _bmad-output/ passes the pause.
# =============================================================================
# The defect the reference consumer filed: Check 3's Write arm never read UPDATER_SESSION, so the
# updater's own prescribed Edit under `planning-artifacts/` (apply.sh's WORKLIST
# `artifact-derivations` row) was denied on every operator reply. Every cell is read BY VALUE --
# verdict, ACK_DENIED rows, ACK_TEAMMATE_WRITE rows, and whether a `File:` line names the path --
# on a fresh tree, and every DENY must carry the Rule 29 reason so Check 2z cannot answer for it.
wexpect() { # <label> <expected cell> <tool> <transcript> [agent_id] <ok sentence> <bad sentence>
  local got; got="$(wcell "$1" "$3" "$4" "${5:-}")"
  if [ "$got" = "$2" ]; then ok "$6"; else bad "$7 (cell '$got', expected '$2')"; fi
}
# The CONTROL for the whole section: without it every ALLOW below is satisfied by a hook that
# allows every write.
wexpect ctl "DENY 1 0 1" Edit "$TR_PIPE_ROUTED" "" \
  "WRITE control: a routed /ai-dlc lead's Edit under planning-artifacts/ is DENIED by the pause, with one attributable ACK_DENIED row" \
  "FIXTURE BROKEN: a pipeline lead's paused Edit is not denied by Rule 29, so every WRITE ALLOW arm below proves nothing"
wexpect typed "ALLOW 0 0 0" Edit "$TR_TYPED" "" \
  "WRITE (i): a typed /ai-dlc-update session's Edit under planning-artifacts/ is ALLOWED while paused, and logs nothing" \
  "WRITE (i): a typed /ai-dlc-update session's Edit under planning-artifacts/ was not a silent allow — the updater's own remedy is denied again"
wexpect tooluse "ALLOW 0 0 0" Edit "$TR_AGENT_POST" "" \
  "WRITE (ii): a Skill(ai-dlc-update) session's Edit under planning-artifacts/ is ALLOWED while paused, and logs nothing" \
  "WRITE (ii): a Skill(ai-dlc-update) session's Edit under planning-artifacts/ was not a silent allow"
wexpect resumed "DENY 1 0 1" Edit "$TR_RESUMED_ROUTED" "" \
  "WRITE (iii): a session whose LAST skill is /ai-dlc, after an updater call, is DENIED — the write exemption follows recency" \
  "WRITE (iii): LEAK — an updater call earlier in the session exempts a resumed pipeline's writes from the pause"
wexpect pipethenupd "ALLOW 0 0 0" Edit "$TR_PIPE_THEN_UPD" "" \
  "WRITE (iii-b): a routed /ai-dlc session whose LAST skill is Skill(ai-dlc-update) is the updater — its Edit is ALLOWED and logs nothing (recency, the other order)" \
  "WRITE (iii-b): a pipeline lead's later Skill(ai-dlc-update) does not make it the updater — the last-skill rule is not what decides"
PTU="$(acell pipethenupd "$TR_PIPE_THEN_UPD")"
if [ "$PTU" = "ALLOW 0" ]; then ok "RECENCY (other order): a routed /ai-dlc session that then calls Skill(ai-dlc-update) dispatches — the LAST skill wins in this direction too"
else bad "RECENCY (other order): a pipeline session's later Skill(ai-dlc-update) did not exempt its Agent dispatch — the transcript scan is not reading the LAST skill (cell '$PTU', expected 'ALLOW 0')"; fi
# THE OTHER ORDER AT THE DISPATCH ITSELF (BL-404). The two cells above read the transcript AFTER the
# updater's tool_use line was flushed. At the Skill(ai-dlc-update) call that line does not exist yet,
# so the transcript's last word is still the typed `/ai-dlc`: the payload is the only signal, and the
# documented rule -- the current call is newer than anything the transcript holds -- makes it win.
# So the dispatch is ALLOWED and logs nothing, and from it on the pause stops binding until `/ai-dlc`
# is invoked again, which the contract accepts. A payload arm that deferred to a transcript skill
# would deny this one call and allow every call after it, a split nothing above can see.
SPU_W="$(seed s-pipethenupd)"
SPU_OUT="$(drive "$SPU_W" Skill "$TR_PIPE_ROUTED" ai-dlc-update)"
if paused_deny "$SPU_OUT"; then SPU=DENY; elif denied "$SPU_OUT"; then SPU=OTHER; else SPU=ALLOW; fi
SPU="$SPU $(rows "$SPU_W" ACK_DENIED)"
if [ "$SPU" = "ALLOW 0" ]; then ok "DISPATCH (other order): a routed typed /ai-dlc session's own Skill(ai-dlc-update) call is ALLOWED and logs nothing — the payload outranks the transcript's last skill"
else bad "DISPATCH (other order): a routed typed /ai-dlc session's Skill(ai-dlc-update) call was not a silent allow — the transcript's last skill overrode the newer payload (cell '$SPU', expected 'ALLOW 0')"; fi
wexpect notranscript "DENY 1 0 1" Edit "$WORK/does-not-exist.jsonl" "" \
  "WRITE (iv): an unreadable transcript's Edit is DENIED (absence of evidence is not the updater)" \
  "WRITE (iv): LEAK — a missing transcript exempts a write from the pause"
wexpect teampipe "ALLOW 0 1 1" Edit "$TR_PIPE_ROUTED" ax \
  "WRITE (v): a teammate's Edit in a pipeline session is ALLOWED and logged as exactly one ACK_TEAMMATE_WRITE naming the file (unchanged)" \
  "WRITE (v): a teammate's paused write in a pipeline session is no longer allowed-and-logged"
wexpect teamupd "ALLOW 0 0 0" Edit "$TR_TYPED" ax \
  "WRITE (vi): a teammate's Edit in an updater session is ALLOWED and logs NOTHING — no pipeline is in flight to quiesce" \
  "WRITE (vi): a teammate's Edit in an updater session is not a silent allow"

# =============================================================================
# M. THE MENTIONS — a quoted typed marker is not an invocation, for Edit AND for Agent.
# =============================================================================
# The write exemption above is only as safe as the updater signal. JSON escapes quotes, not angle
# brackets, so the bare marker quoted anywhere matches the bare pattern; the reference consumer's
# ledger carries it and pipeline sessions read that file. Each mention is the transcript's LAST
# line, in a routed pipeline session, so reading it as an invocation would flip the answer.
mexpect() { # <label> <transcript> <what>
  local we ae
  we="$(wcell "m-$1" Edit "$2")"; ae="$(acell "m-$1" "$2")"
  if [ "$we" = "DENY 1 0 1" ]; then ok "MENTION $1 Edit: $3 does not make a pipeline session the updater — its paused Edit is DENIED"
  else bad "MENTION $1 Edit: LEAK — $3 read as an /ai-dlc-update invocation and a pipeline session's paused Edit passed (cell '$we')"; fi
  if [ "$ae" = "DENY 1" ]; then ok "MENTION $1 Agent: $3 does not make a pipeline session the updater — its paused Agent dispatch is DENIED"
  else bad "MENTION $1 Agent: LEAK — $3 read as an /ai-dlc-update invocation and a pipeline session's paused Agent dispatch passed (cell '$ae')"; fi
}
mexpect read "$TR_M_READ" "a Read of ledger text carrying the typed marker (tool_result, mid-line)"
mexpect text "$TR_M_TEXT" "assistant text quoting the typed marker pair"
mexpect head "$TR_M_HEAD" "a tool_result whose output STARTS with the typed marker pair"

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
