#!/usr/bin/env bash
# ai-dlc-recover-gate.sh -- makes the POST-COMPACT RECOVERY mandate MECHANICAL.
#
# WHAT IT ENFORCES. `ai-dlc-recover.sh` injects a block whose first two sentences are, in
# imperative caps, "Your FIRST tool call MUST be `Read _bmad-output/pipeline-snapshot.md` in
# full" and "Your SECOND tool call MUST be `Read <step file>` in full". Until this hook, that
# was advisory: the injector emits `additionalContext` and has no deny path, no hook in the
# tree parsed a `Read` call, and NOTHING anywhere observed whether the mandated Reads
# happened. `ai-dlc-postcompact.sh` records whether the text was INJECTED -- never whether it
# was OBEYED.
#
# WHY ADVISORY WAS NOT ENOUGH. Filed by the reference consumer as
# PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION. One session skipped both Reads
# on the hook's first firing, skipped both again on a second firing in the same session, and
# on the third attempt stopped 773 of 1210 lines into the second Read, reasoning live that
# finishing was "duplicative" of bytes it had just written. Two silent, one rationalized in
# the open, and all three found only because the operator asked directly. The filing's own
# argument is the one that decides the design: a mandate whose whole purpose is to substitute
# for a lead's possibly-wrong belief that it still holds accurate state cannot delegate to
# that same belief the decision of when the belief is accurate enough to skip it. The
# surrounding hook text already says it -- "You cannot find the cut by introspection."
#
# WHY IT CANNOT WEDGE, WHICH IS THE PART THAT HAD TO BE DESIGNED RATHER THAN ASSERTED.
# A gate that denies until an action is taken is safe only if that action is ALWAYS AVAILABLE.
# So this one arms only when every mandated Read is takeable, and re-checks at deny time:
#
#   - `.recover-fired` must exist. Absent = no compaction is pending recovery, and this hook
#     is inert on every ordinary tool call in every ordinary session.
#   - `step_file_resolved=1`. When a snapshot names no current step file the injected mandate
#     names an ACTION rather than a path, and there is no single call this hook could demand.
#   - Both paths must exist on disk, checked HERE and again before any deny. A path that
#     vanished mid-session disarms the gate instead of blocking every call the lead can make.
#
# Under those conditions "comply" is a Read of a file known to exist, so a deny can always be
# satisfied on the next call. That is the whole safety argument, and it is why this hook is a
# deny rather than the weaker instrumentation option.
#
# IN FULL IS ENFORCED, NOT ASSUMED. The mandate says "in full" and the first shipped version of
# this gate joined on tool name and path only, so `Read <step file> limit=1` cleared the marker
# exactly as a full Read did. `is_full_read()` below is the test. It does not narrow the safety
# argument: the always-available action is the same Read with neither field.
#
# WHAT IT DOES NOT DO. It does not police the THIRD mandated Read -- the post-compact digest,
# `.claude/skills/ai-dlc/postcompact-digest.md`, which the injected text asks for and which
# this hook cannot establish the necessity of from outside. Nor does it police the Read of
# SKILL.md the block asks for on top of that, which is CONDITIONAL by design: it is per-rule,
# taken when the lead is about to act on something the digest only indexes, and a gate cannot
# know from a tool call which rule the lead is about to lean on.
#
# THE ADVISOR STAGE (touchpoint R, BL-545). SKILL.md Rule 32 R: "After the
# `postcompact-digest.md` Read ... call the advisor in the same turn, before your first
# dispatch or write." Measured on the reference consumer: a lead read the snapshot, the step
# file and the digest, dispatched 12 remediators, and called the advisor a minute later, in
# its own words "I haven't made the post-recovery advisor call (touchpoint R) yet". The read
# stages above let the first call after the step Read through, and nothing held the dispatch.
#
# So the call that satisfies the step mandate also writes `.recover-advisor-owed` (the
# session id and a deny count), but only when a `postcompact-digest.md` is readable in either
# layout -- that call is always the LEAD's, because a teammate never reaches the read stages; `.recover-satisfied` is still written
# as before. While that file exists and the read marker does not, an `Agent`, `Task`,
# `TaskCreate`, `Write`, `Edit`, `MultiEdit` or `NotebookEdit` call FROM THE LEAD is judged on the lead's
# transcript: if a Read of `skills/ai-dlc/postcompact-digest.md` follows the last
# `compact_boundary` and no advisor attempt follows that Read, it is DENIED. Every other tool
# is untouched -- the wait-beat a teammate row requires is a Bash call, and R puts it BEFORE the
# advisor call. An advisor attempt after the digest Read clears the stage and deletes the file.
#
# THE DETECTION IS THE ADVISOR GATE'S, restated in one jq pass: an attempt is a
# `server_tool_use` named `advisor`, the grant is the latest `advisor_tool` attachment, and a
# latest `advisor_tool_result` whose `error_code` is `unavailable` means the harness withdrew
# the tool (`ai-dlc-advisor-gate.sh` header, DESIGN). NOT BYTE-BOUND to that copy: there it is
# three arms inside a larger reduce, not a function both files could share, and a binding would
# need that reduce split first. A divergence between the two is a residual no invariant sees.
#
# IT CANNOT WEDGE, by the same argument the read stages make: the action that clears it, an
# advisor call, is available whenever it is enforced, and every state where it is not stands
# the stage down. No grant line, or a withdrawn grant -> the file is deleted and the call
# allowed (a lead on a local model owes no R). A latest result of `unavailable` -> allowed. No
# digest Read since the compaction -> allowed (this stage does not police that Read, the
# injected block does). A teammate (`agent_id` set) -> allowed; R binds the lead. A different
# `session_id` from the one recorded -> the file is stale; deleted, allowed. No readable
# transcript -> allowed. A LOCAL-MODEL LEAD WITH NO GRANT LINE IS NEVER HELD.
#
# THE BOUNDED ESCAPE, because one state is not covered by the grant line: a lead granted the
# tool that then switches to a model without it, where the harness may write no withdrawal.
# Measured on the reference consumer's 174 lead transcripts: 181 grant lines and 0 remove
# lines; 6 transcripts change model, every one local -> Anthropic and none Anthropic -> local
# after a live grant, so the wedge state has 0 recorded instances there -- which is a corpus
# fact, not a guarantee (the advisor gate's header measured a remove line on a `--resume`
# switch to a local model; a `/model` switch was not measured). So the stage refuses at most
# R_MAX_DENIES (3) calls per recovery and then stands down; each deny says so and names the
# `RECOVERY-SKIP: advisor -- <why>` disclosure for a lead that holds no advisor tool.
#
# REGISTRATION. The settings template registers this hook with matcher `*`, so every tool in
# the deny set reaches it; no registration was added.
#
# THE LEAD AND ITS TEAMMATES (BL-590). Both stages bind the lead only. A teammate (`agent_id`
# set) leaves the read path before any stage is read, so it is never refused and its Reads
# never advance or disarm the lead's recovery; the advisor stage has its own stand-down. The
# measurement and the case are at the exit, after the INPUT read.
#
# WHOSE RECOVERY. The read stages used to gate EVERY session in the tree, because the marker
# carried no owner and nothing asked what kind of session was calling. Measured on the reference
# consumer's 179 transcripts: of 78 whose last ai-dlc marker is the updater, 2 were denied the
# snapshot mandate (30 transcripts corpus-wide got it) -- one after real compactions, one with no
# compact_boundary at all, denied 11 seconds after /ai-dlc-update by a marker another session left.
# So the read stages now stand down, WITHOUT deleting the marker (it may be a real lead's pending
# recovery), for (1) a call whose session_id differs from the one the marker records and (2) a
# call whose own transcript's last ai-dlc marker is the updater (the I126 scan). A marker with
# no session_id, or a call with none, keeps the old behaviour. The advisor stage needs neither:
# it is armed only by the call that satisfied the reads, is keyed on that session_id and
# deletes its file for any other, and an update session never satisfies the step Read. A
# teammate is the same session as its lead to the session_id key (a subagent's calls carry the
# parent's sessionId), so the teammate exit above, not this key, is what separates them.
#
# THE RACE. The incoming call's own message is usually not on disk when PreToolUse fires
# (measured in the advisor gate's header, THE RACE), so an advisor call in the same message
# may not be visible yet. A DENY is therefore re-judged every 0.25s until the incoming call's
# own `tool_use` line lands or 10s pass; an ALLOW is final at once. The deny reason says to
# call the advisor in a message of its own, which is the shape that never races.
#
# It does not read the lead's prose, so the RECOVERY-SKIP disclosure the block
# requires is not verifiable here -- that disclosure covers exactly the cases where this gate
# could not arm, and the block says so.
#
# PROTOCOL. PreToolUse hook: reads the tool call as JSON on stdin, emits a JSON decision on
# stdout. Deny is `permissionDecision: "deny"`, never exit code 2 -- the contract
# `ai-dlc-protect.sh` established and four other guards follow. Silence (exit 0, no output)
# leaves the call to the harness's normal permission flow.
#
# Compatible with bash 3.2. Requires jq; without it the hook exits silently rather than
# guessing at the payload, because a guard that cannot read its input must not deny.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="${PROJECT_DIR}/_bmad-output"
MARKER="${STATE_DIR}/.recover-fired"
PROGRESS="${STATE_DIR}/.recover-gate-progress"
OWED="${STATE_DIR}/.recover-advisor-owed"
R_MAX_DENIES=3
# The digest the stage keys on, in either layout. Unreadable in both -> the stage never arms.
digest_readable() {
  [ -r "${PROJECT_DIR}/.claude/skills/ai-dlc/postcompact-digest.md" ] \
    || [ -r "${PROJECT_DIR}/core/skills/ai-dlc/postcompact-digest.md" ]
}
# owed_put <session_id> <denies> -- the ONE writer of the owed file. A failed write warns on
# stderr naming the hook and the file and never denies: an unwritten arm leaves the stage
# disarmed (fail open), and an unwritten count leaves the next deny at the same count.
owed_put() {
  printf 'session_id=%s\ndenies=%s\n' "$1" "$2" > "$OWED" 2>/dev/null \
    || echo "WARN: ai-dlc-recover-gate: could not write $OWED" >&2
}

# --- THE ADVISOR STAGE (header: THE ADVISOR STAGE) ---------------------------------------
# Runs only once the read stages have disarmed (no marker) and left the owed file behind, so
# it costs one `[ -f ]` on every ordinary call and never overlaps a read stage.
if [ ! -f "$MARKER" ] && [ -f "$OWED" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  R_IN="$(cat 2>/dev/null || true)"
  R_TOOL=""; R_AID=""; R_SID=""; R_TP=""; R_TUID=""
  R_P="$(printf '%s' "$R_IN" | jq -r '@sh "R_TOOL=\((.tool_name // "") | tostring) R_AID=\((.agent_id // "") | tostring) R_SID=\((.session_id // "") | tostring) R_TP=\((.transcript_path // "") | tostring) R_TUID=\((.tool_use_id // "") | tostring)"' 2>/dev/null)" || exit 0
  eval "$R_P"
  case "$R_TOOL" in Agent|Task|TaskCreate|Write|Edit|MultiEdit|NotebookEdit) : ;; *) exit 0 ;; esac
  [ -z "$R_AID" ] || exit 0
  R_OSID="$(sed -n 's/^session_id=//p' "$OWED" 2>/dev/null | head -1)"
  if [ -n "$R_OSID" ] && [ -n "$R_SID" ] && [ "$R_OSID" != "$R_SID" ]; then
    rm -f "$OWED" 2>/dev/null || true
    exit 0
  fi
  # THE BOUNDED ESCAPE (header: THE ADVISOR STAGE). After R_MAX_DENIES refusals the stage stands
  # down for this recovery, whatever the transcript says.
  R_DENIES="$(sed -n 's/^denies=//p' "$OWED" 2>/dev/null | head -1)"
  case "$R_DENIES" in ''|*[!0-9]*) R_DENIES=0 ;; esac
  if [ "$R_DENIES" -ge "$R_MAX_DENIES" ]; then
    rm -f "$OWED" 2>/dev/null || true
    exit 0
  fi
  [ -n "$R_TP" ] && [ -r "$R_TP" ] || exit 0
  # One pass: grant (latest advisor_tool attachment), dig (line of the last digest Read after
  # the last compact_boundary, 0 if none), adv (line of the last advisor attempt), res (U when
  # the latest advisor result is `unavailable`), seen (the incoming call's own line is on disk).
  r_scan() {
    jq -n -R -r --arg tuid "$R_TUID" '
      reduce (inputs | (fromjson? // empty) as $l | select(($l | type) == "object") | [input_line_number, $l]) as [$n, $l]
        ({grant: null, dig: 0, adv: 0, res: "-", seen: 0};
         if ($l.type == "attachment" and ($l.attachment | type) == "object" and $l.attachment.type == "advisor_tool") then
           .grant = (($l.attachment.available != false) and ($l.attachment.toolChange != "remove"))
         elif ($l.type == "system" and $l.subtype == "compact_boundary") then .dig = 0
         else
           reduce ((($l.message.content? // []) | if type == "array" then .[] else empty end | select(type == "object"))) as $b (.;
             if ($b.type == "server_tool_use" and $b.name == "advisor") then .adv = $n
             elif $b.type == "advisor_tool_result" then
               .res = (if (($b.content | if type == "object" then .error_code else null end) // "") == "unavailable" then "U" else "R" end)
             elif ($b.type == "tool_use" and $b.name == "Read"
                   and ((($b.input.file_path // "") | tostring) | test("(^|/)skills/ai-dlc/postcompact-digest\\.md$"))) then .dig = $n
             elif ($b.type == "tool_use" and $tuid != "" and (($b.id // "") | tostring) == $tuid) then .seen = 1
             else . end)
         end)
      | "\(if .grant == null then "none" elif .grant then "on" else "off" end) \(.dig) \(.adv) \(.res) \(.seen)"' "$R_TP" 2>/dev/null
  }
  # r_judge: sets R_V to allow | clear | owed from R_STATE.
  r_judge() {
    read -r R_GRANT R_DIG R_ADV R_RES R_SEEN <<<"$R_STATE"
    R_V=owed
    [ "${R_DIG:-0}" -gt 0 ] 2>/dev/null || R_V=allow
    if [ "$R_V" = owed ] && [ "${R_ADV:-0}" -gt "${R_DIG:-0}" ] 2>/dev/null; then R_V=clear; fi
    if [ "$R_V" = owed ] && [ "${R_RES:--}" = U ]; then R_V=allow; fi
    return 0
  }
  R_STATE="$(r_scan)" || exit 0
  [ -n "$R_STATE" ] || exit 0
  r_judge
  if [ "${R_GRANT:-none}" != on ]; then rm -f "$OWED" 2>/dev/null || true; exit 0; fi
  _rt0=$SECONDS
  while [ "$R_V" = owed ] && [ "${R_SEEN:-0}" != 1 ] && [ $((SECONDS - _rt0)) -lt 10 ]; do
    sleep 0.25
    R_S2="$(r_scan)" || R_S2=""
    [ -n "$R_S2" ] && R_STATE="$R_S2"
    r_judge
  done
  if [ "$R_V" = clear ]; then rm -f "$OWED" 2>/dev/null || true; exit 0; fi
  [ "$R_V" = owed ] || exit 0
  owed_put "$R_OSID" "$((R_DENIES + 1))"
  jq -n --arg m "AI/DLC post-compact recovery: SKILL.md Rule 32 touchpoint R is owed. You read postcompact-digest.md after this compaction and have made no advisor call since, so this ${R_TOOL} call -- a dispatch or a write -- is refused ($((R_DENIES + 1)) of ${R_MAX_DENIES}). Call the advisor in a message of its own, read its answer, then retry the same call. Any advisor attempt clears this, including one that errors; if the advisor answers 'unavailable' this gate stands down. If you hold no advisor tool, say so in one line (RECOVERY-SKIP: advisor -- <why>) and retry: after ${R_MAX_DENIES} refusals this stage stands down. Arming a wait-beat (Bash) is not refused and belongs before the advisor call." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $m}}'
  exit 0
fi

# Inert unless a compaction is actually pending recovery. This is the common case by a very
# large margin and it must cost nothing.
#
# THIS CHECK IS A PERFORMANCE FAST-PATH, NOT THE BEHAVIOURAL GUARD, and that distinction is
# recorded because a mutant proved it: deleting this line alone changes NO verdict. With the
# marker absent every `mval` returns empty and the key checks below stand the hook down for
# the same cases. What the line actually buys is that an ordinary tool call in an ordinary
# session -- which is nearly all of them, on a hook registered against every tool -- returns
# here without forking `jq`, reading stdin, or running four `sed` passes.
#
# So it is not a vacuous guard to be deleted by the next reader tidying up; its subject is
# cost, and the fixture asserts that subject directly rather than through a verdict flip.
[ -f "$MARKER" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0

# THE READ STAGES BIND THE LEAD ONLY (BL-590). The marker is project-wide and the matcher is
# `*`, so before this line a TEAMMATE's call during the lead's pending recovery was refused with
# text addressed to the lead -- measured on the reference consumer: 253 such denials across 113
# subagent transcripts. And a teammate's Reads ADVANCED the lead's stages: in graph session
# d5ba4ec4 a teammate's full Read of the step file cleared the marker, the lead's first
# post-compact calls included an Edit of pipeline-snapshot.md with no deny, and the lead read
# its step file two minutes later. A teammate reading the snapshot reloads nothing into the
# lead's context, so it neither is refused nor counts toward the recovery: it leaves here, before
# any stage is read, advanced or denied. `.agent_id` is set only on a call made inside a
# dispatched teammate, as `ai-dlc-acknowledge.sh` reads it. Below the marker fast-path on
# purpose, so an ordinary call still forks nothing, and below the advisor stage, which carries
# its own teammate stand-down.
RG_AGENT="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)"
[ -z "$RG_AGENT" ] || exit 0

# --- what the injector recorded ----------------------------------------------------------
# Read as key=value lines, never sourced: `.` on a file in the project directory would execute
# whatever a consumer's tree happened to put there.
mval() { sed -n "s/^$1=//p" "$MARKER" 2>/dev/null | head -1; }

# THE UNARMABLE READ IS ONE FORK, NOT THREE, AND THE ORDER IS THE WHOLE REASON. A recovery the
# injector REFUSED -- it names no step file, or its Pipeline Position named more than one and
# ai-dlc-recover.sh declined to pick -- leaves a marker on disk for the rest of the session,
# because that marker is ai-dlc-postcompact.sh's record that the injection happened and deleting
# it would make the compaction log under-report. So `[ -f "$MARKER" ]` above stops being the
# fast path for those sessions: every later tool call reaches here. Reading all three keys
# before testing any of them spent two `sed` forks per call to learn something the first key
# already decided. The stand-down checks are unchanged in effect and each still has its own
# line, which is what keeps them separately mutable.
STEP_RESOLVED="$(mval step_file_resolved)"

# A marker written before this hook existed carries none of these keys. Treat that exactly as
# "cannot arm" -- an older marker is not evidence about a mandate it never recorded.
[ "$STEP_RESOLVED" = "1" ] || exit 0

SNAP_REL="$(mval snapshot_path)"
STEP_REL="$(mval step_file)"

[ -n "$SNAP_REL" ] || exit 0
[ -n "$STEP_REL" ] || exit 0

# TWO STAND-DOWNS FOR A CALL THIS RECOVERY IS NOT OWED TO (header: WHOSE RECOVERY). Both sit
# ABOVE the readability block, because that block deletes the marker and a call that is not the
# lead's must never be the one to clear a recovery the lead still owes. Neither deletes anything.
# Both are keyed on the INCOMING call and fail toward the existing gate: an absent field, an
# unreadable transcript or a marker from before the key existed leaves the deny path as it was.
G_SID=""; G_TP=""
G_P="$(printf '%s' "$INPUT" | jq -r '@sh "G_SID=\((.session_id // "") | tostring) G_TP=\((.transcript_path // "") | tostring)"' 2>/dev/null)" && eval "$G_P"
# 1. A marker another session wrote. Both ids must be present and different.
M_SID="$(mval session_id)"
if [ -n "$M_SID" ] && [ -n "$G_SID" ] && [ "$M_SID" != "$G_SID" ]; then
  exit 0
fi
# 2. An update session, whatever wrote the marker: the recovery mandate is the lead's.
if [ -n "$G_TP" ] && [ -r "$G_TP" ]; then
  TRANSCRIPT="$G_TP"
  # >>> I126 SESSION-MARKER SCAN: the next line, byte-identical in every bound hook >>>
  LAST_SKILL=$(grep -oE '"role":"user","content":"<command-message>ai-dlc(-update)?</command-message>\\n<command-name>/ai-dlc(-update)?</command-name>|"name":"Skill","input":\{"skill":"ai-dlc(-update)?"' "$TRANSCRIPT" 2>/dev/null | tail -1)
  case "$LAST_SKILL" in
    *'/ai-dlc-update</command-name>'|*'"skill":"ai-dlc-update"') exit 0 ;;
  esac
fi

# ARMING PRECONDITION, RE-CHECKED ON EVERY CALL. If either mandated file is not readable now,
# the gate stands down permanently for this recovery: it clears the marker so it does not
# re-arm, and lets the call through. Denying a Read of something absent is the wedge.
resolve() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "${PROJECT_DIR}/$1" ;; esac; }
SNAP_ABS="$(resolve "$SNAP_REL")"
STEP_ABS="$(resolve "$STEP_REL")"
if [ ! -r "$SNAP_ABS" ] || [ ! -r "$STEP_ABS" ]; then
  rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true
  exit 0
fi

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
FPATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
LIMIT="$(printf '%s' "$INPUT" | jq -r '.tool_input.limit // empty' 2>/dev/null)"
OFFSET="$(printf '%s' "$INPUT" | jq -r '.tool_input.offset // empty' 2>/dev/null)"

# "IN FULL" IS PART OF THE MANDATE AND IT WAS THE THIRD SKIP THE FILING RECORDED -- a lead that
# started the second mandated Read and stopped 773 of 1210 lines in, reasoning live that the
# remainder was duplicative. Until this test the gate joined on tool name and path alone, so
# `Read <step file> limit=1` satisfied it exactly as a full Read did: marker cleared, gate inert,
# 1 line of 1210 loaded. `limit` bounds the read; an `offset` past the first line starts it late.
# Either is a partial. No limit and no offset past line 1 is the full read.
#
# IT CANNOT WEDGE, which is the same argument the arming precondition makes. The always-available
# action is the identical Read with neither field -- the harness TRUNCATES an over-long Read
# rather than refusing it, so that call is issuable for any file, and the block above has already
# established this one is readable. A deny here is satisfiable on the very next call.
is_full_read() {
  [ -z "$LIMIT" ] || return 1
  case "$OFFSET" in ""|0|1) return 0 ;; *) return 1 ;; esac
}

# Normalise the call's path the same way, so `Read _bmad-output/x.md` and an absolute form of
# the same file are one answer. A gate that matched only one spelling would deny a compliant
# call, which is a wedge wearing a different hat.
FABS=""
[ -n "$FPATH" ] && FABS="$(resolve "$FPATH")"

STAGE="$(cat "$PROGRESS" 2>/dev/null || printf 'snapshot')"

# PROVENANCE MARKER -- PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL. The
# library is a SIBLING in both layouts (core/hooks/, .claude/hooks/), so this is a
# same-directory read and never a walk up from a resolved path. Fail-open: a hook
# that cannot mark its output still emits it.
_AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi

deny() {
  jq -n --arg reason "$1" --arg context "$(ai_dlc_provenance_wrap ai-dlc-recover-gate PreToolUse "$2")" \
    '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason,
        additionalContext: $context
      }
    }'
  exit 0
}

case "$STAGE" in
  snapshot)
    if [ "$TOOL" = "Read" ] && [ -n "$FABS" ] && [ "$FABS" = "$SNAP_ABS" ]; then
      if is_full_read; then
        printf 'step\n' >"$PROGRESS" 2>/dev/null || true
        exit 0
      fi
      deny "AI/DLC post-compact recovery: \`Read ${SNAP_REL}\` must be IN FULL, and this call bounds it with \`limit\`/\`offset\`. Re-issue the same Read with neither field." \
"A bounded Read of the snapshot is the skip wearing the shape of compliance --
the gate would clear and the pipeline state you did not load would be the state
you act on. Call \`Read ${SNAP_REL}\` again with no \`limit\` and no \`offset\`;
that call is available to you now."
    fi
    deny "AI/DLC post-compact recovery: your FIRST tool call must be \`Read ${SNAP_REL}\` in full. This conversation was compacted and the summary is not the authoritative pipeline state." \
"The snapshot is a verbatim-load file and the Read is the attention interrupt that
defeats reconstructing state from the summary. Call it now, in full, with the
native Read tool -- never a \`ctx_*\` tool. Then \`Read ${STEP_REL}\` in full. Both
files were confirmed present before this gate armed, so complying is available to
you on the next call; there is nothing here to weigh."
    ;;
  step)
    if [ "$TOOL" = "Read" ] && [ -n "$FABS" ] && [ "$FABS" = "$STEP_ABS" ]; then
      if is_full_read; then
        # SATISFIED. Clear both, so the gate is inert for the rest of the session until the
        # next compaction writes a fresh marker.
        #
        # THE BREADCRUMB IS WRITTEN BEFORE THE CLEAR, AND IT EXISTS FOR A HOOK THAT RUNS AFTER
        # THIS ONE. `ai-dlc-handoff-entry.sh` is PostToolUse on `Read`; this gate is PreToolUse
        # on every tool. So on the call that satisfies the second mandate the order is: this
        # hook runs, the Read executes, the entry hook runs. If the entry hook tried to decide
        # from `$MARKER` it would be testing a file this line removed one hook earlier, and it
        # would arm the handoff marker on a Read the recovery COMPELLED -- the exact case it
        # exists to prevent, invisible to any seed that does not drive both hooks in shipped
        # order.
        #
        # SO THE STATE IS HANDED FORWARD EXPLICITLY. This records WHICH Read was the satisfying
        # one, which is strictly more than `$MARKER` ever knew: the marker says "a recovery is
        # in flight", never "THIS call is the one it demanded". A lead that satisfied only the
        # FIRST mandate and then opened the step file of its own accord is a genuine
        # initiation, and it must still arm -- the marker alone cannot tell that apart from
        # this case, and this breadcrumb can, because only the satisfying call writes it.
        #
        # ONE-SHOT BY CONSTRUCTION. The consumer deletes it, so it cannot accumulate and it
        # cannot answer for a later Read. A stale copy that somehow survives is bounded the
        # same way the marker is: `ai-dlc-recover.sh` removes it when a NEW recovery starts,
        # so it can never outlive the recovery that wrote it.
        printf 'step_file=%s\n' "$STEP_REL" > "${STATE_DIR}/.recover-satisfied" 2>/dev/null || true
        # THE ADVISOR STAGE ARMS HERE (header: THE ADVISOR STAGE). Keyed on the session that
        # satisfied the reads, so another session's call in the same project stands it down.
        # Only the lead reaches this line (a teammate left at the BL-590 exit above), and a tree
        # with no readable digest does not arm it: R follows the digest Read, so without the
        # file R is not owed.
        if digest_readable; then
          owed_put "$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)" 0
        fi
        rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true
        exit 0
      fi
      deny "AI/DLC post-compact recovery: \`Read ${STEP_REL}\` must be IN FULL, and this call bounds it with \`limit\`/\`offset\`. Re-issue the same Read with neither field." \
"This is the exact skip this gate was filed for: the second mandated Read was
started and abandoned partway on the judgment that the remainder was duplicative
-- a judgment made from inside the state the Read exists to replace. Call
\`Read ${STEP_REL}\` again with no \`limit\` and no \`offset\`."
    fi
    # Re-reading the snapshot is not progress, but it is not a violation either -- it is the
    # call this gate just demanded. Allow it without advancing, so a lead that reads it twice
    # is not punished for the harness replaying a call.
    if [ "$TOOL" = "Read" ] && [ -n "$FABS" ] && [ "$FABS" = "$SNAP_ABS" ]; then
      exit 0
    fi
    deny "AI/DLC post-compact recovery: your SECOND tool call must be \`Read ${STEP_REL}\` in full. Compaction cleared the harness's record of every file previously read, so the step file is not loaded no matter how recently you read it." \
"Measured across 265 real compactions, this Read lands 41% of the time against the
snapshot Read's 66% -- it is the one most often skipped and the one this gate
exists for. Read it IN FULL: stopping partway because the remainder looks
duplicative is a judgment made from inside the state the Read exists to replace.
The file was confirmed present before this gate armed."
    ;;
  *)
    # An unreadable progress value means state this hook cannot reason about. Stand down
    # rather than deny on a guess.
    rm -f "$PROGRESS" 2>/dev/null || true
    exit 0
    ;;
esac
