#!/bin/bash
#
# AI/DLC handoff entry marker
#
# PostToolUse on `Read`. When the lead reads steps/handoff.md it is inside the handoff
# procedure, and this records that fact on disk so a compaction landing on any turn of the
# five steps can be routed back to the same file. `ai-dlc-recover.sh` reads the marker
# through ai-dlc-handoff-pending.sh; steps/handoff.md removes it at step 5.
#
# WHY A HOOK AND NOT THE STEP FILE. The step file was the first cut: an instruction to
# `touch` the marker before step 1. It was wrong twice over. schemas/pipeline-state-paths.json
# classifies "every top-level entry the shipped MACHINERY constructs", and its `producer`
# field is explicitly "a shipped file that CONSTRUCTS this path on a non-comment line" -- a
# file that only tells a lead to construct it does not satisfy I95, which failed the push and
# was right to. And the defect this whole change exists for is a lead that did not execute the
# handoff procedure at all, so a marker whose only writer is that same procedure is absent in
# precisely the case that motivated it. The consumer's own filing said so in its One limit:
# the fix needs "a mechanical marker a hook can check, not just prose".
#
# NEVER BLOCKS, AND IS NOT A GATE. PostToolUse runs after the call has returned; the Read has
# already happened. Every path exits 0, including every failure path -- a marker hook that
# could fail a tool call would make the pipeline's ability to read a step file depend on its
# ability to write a file.
#
# AND IT IS NOT EVERY READ OF THAT FILE. A compaction's recovery MANDATES a Read of the step
# file and points that mandate here whenever a handoff is already pending, so arming on the
# path alone wrote the marker from a Read the machinery compelled. The suppression is sited at
# the arming decision below, keyed on the SATISFACTION BREADCRUMB `ai-dlc-recover-gate.sh`
# writes on the call that discharges the second mandate -- not on the in-flight marker, which
# that gate has already deleted by the time this PostToolUse hook runs.
#
# LEAD ONLY. The marker is project-wide, so it is written from the LEAD's Read and never from a
# dispatched teammate's, the same lead-only binding `ai-dlc-recover-gate.sh` carries. The
# discriminator is the payload's `agent_id`; the reasoning is at the exit below.
#
# THE MATCH IS ON THE BASENAME UNDER A steps/ PARENT, not on a whole path. The same file lives
# at .claude/skills/ai-dlc/steps/handoff.md on a consumer and core/skills/ai-dlc/steps/handoff.md
# in the distribution, and a lead may read it through either spelling or through a relative
# path. Anchoring on the two path segments matches every layout without matching a consumer's
# own unrelated `handoff.md` somewhere else in the tree.
#
# WHY NOT ALSO REMOVE IT HERE. The marker means "inside the procedure", and this hook cannot
# see the procedure END -- step 5 is a Bash call, not a Read. steps/handoff.md removes it,
# beside the pause flag, where the procedure knows it has finished. A stale marker with the
# pause flag already gone is inert: ai_dlc_handoff_pending requires the flag first.
#
# IT ALSO CLOSES A GATE THE LEAD WALKED OUT OF. `.gate-checkpoint/OPEN` is removed only by
# `gate-checkpoint.sh close`, a duty carried by the gate file's prose alone, and the marker that
# stands after a lead moves on is resumed by the next compaction and silently overwritten by the
# next `open`. The next step's entry is the one act that marks the leave, and this is the hook that
# already sees step Reads, so it is sited here rather than in a new hook. It CLOSES and never
# refuses: `ai-dlc-recover-gate.sh` forces a whole Read of the snapshot's step after every
# compaction, and a refusing entry would deadlock against that mandate in exactly the case the lead
# compacted -- 3 of 43 compactions measured inside a live gate forced a Read of ANOTHER step, the
# lead returning to the unfinished gate within 5 s to 15 min each time.
#
# The rule, over the step basename `x` under `skills/ai-dlc(-update)?/steps/` (the regex is
# ai-dlc-recover.sh's, byte for byte):
#   - `gate-validation`, `_*`, `route` and `handoff` are EXCLUDED: they never leave a gate and never
#     record a step. `route` is read first on every `/ai-dlc` invocation, resume included, so a
#     close on it would close a live gate because the lead resumed; `handoff` is the pause
#     procedure, taken mid-gate (2 of the 7 measured leaves went to it, and one of those gates was
#     recorded in later in the same session and closed deliberately by a later session).
#   - WHOLE means no `offset` and no `limit` key, the rule ai-dlc-recover.sh's transcript reading
#     uses. It is NOT recover-gate's `is_full_read`, which also accepts offset 0 or 1.
#   - With no gate open, a Read of a non-excluded step records `.gate-checkpoint/STEP` =
#     `<x><TAB><session_id>` -- the step entered, and the session that entered it -- but only when
#     `.gate-checkpoint/` already exists: a plain Read never creates pipeline state. So a tree's
#     FIRST gate has no STEP and is not closed here; `open` creates the directory, and every later
#     gate is covered. That is a degrade to the prior behaviour, not a refusal.
#   - With a gate open, a WHOLE Read of STEP's own step rebinds STEP to the reading session, and a
#     WHOLE Read of another non-excluded step BY STEP'S SESSION runs `gate-checkpoint.sh close` at
#     the OPEN nonce. Only after that close succeeds does it write `.gate-checkpoint/LEFT` =
#     `<nonce><TAB><x><TAB><the gate's own step, STEP's>` -- a record of the event, never of intent;
#     the field order is gate-checkpoint.sh's, whose re-open puts STEP back on that third field so the
#     lead's next whole Read of the gate's own step is not read as another leave -- and print ONE
#     additionalContext object saying `record` or `done` at that nonce re-opens the gate.
#   - THE SESSION BINDING IS NOT A CONCURRENCY GUARD. After a handoff mid-gate the next session's
#     first whole Read of the snapshot's next step carries no recovery breadcrumb, because the
#     recovery gate arms only on a compaction; without the binding that Read would close the
#     paused, live gate. It also keeps another lead session on the same tree from closing this
#     session's gate. A session that resumes the gate rebinds it by reading the gate's own step.
#   - A FORCED READ IS NOT AN ENTRY. When the satisfaction breadcrumb names `x`, the Read -- of any
#     shape -- with a gate open only rebinds STEP's session; with none open it records STEP for a
#     non-excluded `x` as any entry does, since it is the lead's position and a STEP left naming an
#     older step would turn the next gate's re-read of its own step into a leave. For a non-handoff
#     `x` it consumes the breadcrumb so
#     a later genuine Read of `x` is a real entry (for handoff.md the block further down stays the
#     one consumer). The breadcrumb is read where its one writer puts it, `_bmad-output/` --
#     recover-gate does not honour AI_DLC_STATE_DIR -- and under the state dir when the two differ.
#     A breadcrumb naming another step stays until the next recovery clears it; after a forced
#     exemption a forgotten close stands until the lead's next genuine whole Read of another step.
# Replayed over 160 lead and 6207 subagent transcripts in time order this rule made one close, 3 s
# before that lead's own close, and none inside a window where the gate was still being worked; the
# same replay with the forced-Read exemption removed made five, four of them inside worked windows.
# Anything unreadable -- no session id, no STEP, no OPEN, no checkpoint script -- does nothing, and
# so does a state dir other than `_bmad-output` until recover-gate honours AI_DLC_STATE_DIR (the
# guard at the block says why, and which release lifts it).
#
# INSTALL
#   .claude/settings.json:
#     "PostToolUse": [{ "matcher": "Read",
#       "hooks": [{ "type": "command",
#                   "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-handoff-entry.sh" }] }]

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"

INPUT="$(cat 2>/dev/null || true)"
[ -n "$INPUT" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
[ "$TOOL" = "Read" ] || exit 0

FPATH="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$FPATH" ] || exit 0

# THE GATE-LEAVE CLOSE (header: "IT ALSO CLOSES A GATE"). Every path through it falls through to
# the handoff block below unchanged; it never exits.
case "$FPATH" in
  *skills/ai-dlc*/steps/*.md)
    _m1="$(printf '%s' "$INPUT" | jq -r '(.agent_id // "" | tostring), (.session_id // "" | tostring),
      (if ((.tool_input | has("offset")) or (.tool_input | has("limit"))) then "S" else "W" end),
      ([(.tool_input.file_path // "") | tostring | capture("skills/ai-dlc(-update)?/steps/(?<s>[A-Za-z0-9_.-]+)\\.md$")][0].s // "")' 2>/dev/null)"
    _m1_aid=""; _m1_sid=""; _m1_shape=""; _m1_x=""
    { IFS= read -r _m1_aid; IFS= read -r _m1_sid; IFS= read -r _m1_shape; IFS= read -r _m1_x; } <<<"$_m1"
    # LEAD ONLY, for the reason the exit further down gives: a teammate's Read is not the lead
    # entering a step, and must not consume the breadcrumb the lead's compelled Read still needs.
    # It empties the step rather than exiting, so for handoff.md the exit further down stays the
    # one that decides -- an exit here would shadow it and leave that exit with no subject.
    [ -z "$_m1_aid" ] || _m1_x=""
    # INERT OFF THE DEFAULT STATE DIR. ai-dlc-recover-gate.sh reads its arming marker at the literal
    # `_bmad-output/.recover-fired` while ai-dlc-recover.sh writes it under AI_DLC_STATE_DIR, so on
    # any other state dir the gate never arms and never writes the breadcrumb. With no breadcrumb a
    # forced post-compaction Read of another step is indistinguishable from a leave and would close
    # a live gate -- the 3-of-43 case above. So the whole block does nothing there: no STEP, no
    # rebind, no close, which is the prior behaviour. Cluster F10, which makes recover-gate honour
    # AI_DLC_STATE_DIR, must lift this guard; until then the state-dir half of the breadcrumb read
    # below names the same file as the first half and is kept only for that release.
    [ "$STATE_DIR" = "${PROJECT_DIR}/_bmad-output" ] || _m1_x=""
    _m1_dir="${STATE_DIR}/.gate-checkpoint"
    _m1_open=""; _m1_st=""; _m1_ss=""
    [ -f "${_m1_dir}/OPEN" ] && read -r _m1_open < "${_m1_dir}/OPEN" 2>/dev/null
    [ -f "${_m1_dir}/STEP" ] && IFS="$(printf '\t')" read -r _m1_st _m1_ss < "${_m1_dir}/STEP" 2>/dev/null
    # Forced Read: the breadcrumb names this step, under recover-gate's literal dir or the state dir.
    _m1_forced=0
    for _m1_rs in "${PROJECT_DIR}/_bmad-output/.recover-satisfied" "${STATE_DIR}/.recover-satisfied"; do
      [ -n "$_m1_x" ] && [ -f "$_m1_rs" ] || continue
      _m1_rsf="$(sed -n 's/^step_file=//p' "$_m1_rs" 2>/dev/null | head -1)"
      case "$_m1_rsf" in
        */steps/"$_m1_x".md|steps/"$_m1_x".md)
          _m1_forced=1
          [ "$_m1_x" = "handoff" ] || rm -f "$_m1_rs" 2>/dev/null || true
          break ;;
      esac
    done
    # _m1_w: the step STEP is to name for this session (empty: STEP is not written).
    _m1_close=0; _m1_w=""
    _m1_excl=0
    case "$_m1_x" in
      gate-validation|route|handoff|_*) _m1_excl=1 ;;
    esac
    if [ -z "$_m1_x" ] || [ -z "$_m1_sid" ] || [ ! -d "$_m1_dir" ]; then
      :
    elif [ "$_m1_forced" = 1 ]; then
      # With a gate open: rebind only -- keep the step, take the session. With none open the forced
      # Read IS the lead's position, so it records STEP exactly as a genuine entry does (excluded
      # steps record nothing); a stale STEP would make the next gate's re-read of its own step a leave.
      if [ -n "$_m1_open" ]; then
        [ -n "$_m1_st" ] && _m1_w="$_m1_st"
      elif [ "$_m1_excl" = 0 ]; then
        _m1_w="$_m1_x"
      fi
    elif [ "$_m1_excl" = 1 ]; then
      :
    elif [ -z "$_m1_open" ]; then
      _m1_w="$_m1_x"
    elif [ -z "$_m1_st" ] || [ "$_m1_shape" != "W" ]; then
      :
    elif [ "$_m1_x" = "$_m1_st" ]; then
      _m1_w="$_m1_st"
    elif [ "$_m1_ss" = "$_m1_sid" ]; then
      _m1_close=1
    fi
    if [ "$_m1_close" = 1 ]; then
      # Located by the literal pair ai-dlc-recover.sh uses, never walked up (I33). `--root` pins
      # the close to the tree whose OPEN was just read: a close resolved against another root
      # finds no marker, exits 0, and would be reported here as a close that never happened.
      _m1_ckp=""
      for _m1_c in "${PROJECT_DIR}/scripts/ai-dlc/gate-checkpoint.sh" "${PROJECT_DIR}/core/scripts/gate-checkpoint.sh"; do
        if [ -x "$_m1_c" ]; then _m1_ckp="$_m1_c"; break; fi
      done
      if [ -n "$_m1_ckp" ] \
         && bash "$_m1_ckp" --root "$PROJECT_DIR" --nonce "$_m1_open" close >/dev/null 2>&1 \
         && [ ! -f "${_m1_dir}/OPEN" ] \
         && printf '%s\t%s\t%s\n' "$_m1_open" "$_m1_x" "$_m1_st" > "${_m1_dir}/LEFT.$$" 2>/dev/null \
         && mv "${_m1_dir}/LEFT.$$" "${_m1_dir}/LEFT" 2>/dev/null; then
        _m1_w="$_m1_x"
        _AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
        if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
        else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi
        _m1_msg="Gate \`${_m1_open}\` was closed: this session left it at its whole Read of \`${_m1_x}.md\` without a \`close\`. If it is unfinished, \`gate-checkpoint.sh --nonce ${_m1_open} record|done\` re-opens it."
        jq -n --arg context "$(ai_dlc_provenance_wrap ai-dlc-handoff-entry PostToolUse "$_m1_msg")" '{
          hookSpecificOutput: {
            hookEventName: "PostToolUse",
            additionalContext: $context
          }
        }' 2>/dev/null || true
      else
        rm -f "${_m1_dir}/LEFT.$$" 2>/dev/null || true
      fi
    fi
    # STEP is written only on a record, a rebind, or the step just entered after a close.
    if [ -n "$_m1_w" ]; then
      printf '%s\t%s\n' "$_m1_w" "$_m1_sid" > "${_m1_dir}/STEP.$$" 2>/dev/null \
        && mv "${_m1_dir}/STEP.$$" "${_m1_dir}/STEP" 2>/dev/null || rm -f "${_m1_dir}/STEP.$$" 2>/dev/null || true
    fi
    ;;
esac

case "$FPATH" in
  */steps/handoff.md) : ;;
  *) exit 0 ;;
esac

# THE MARKER IS THE LEAD'S, AND A DISPATCHED TEAMMATE'S READ IS NOT THE LEAD ENTERING THE
# PROCEDURE.
#
# `.handoff-in-progress` is project-wide and key 1 of `ai_dlc_handoff_pending`: it arms the Stop
# guard and reroutes the next compaction's mandate for the WHOLE session. A teammate that reads
# steps/handoff.md therefore armed the lead's marker, the shape `ai-dlc-recover-gate.sh` was
# bound against so that its denials apply to the lead only. PostToolUse carries a non-empty
# `agent_id` for a subagent's call and no such key for the lead's. `agent_type` is NOT the
# discriminator: a lead started with `claude --agent` carries `agent_type` and no `agent_id`,
# and it is still the lead.
#
# SITED HERE, BEFORE THE BREADCRUMB BLOCK BELOW, AND NOT AFTER IT. That block DELETES
# `.recover-satisfied` as it reads it. An exit placed after it lets a teammate's Read consume
# the breadcrumb the LEAD's compelled Read still needs, and the lead's Read then arms the
# marker from a recovery-mandated call. Fail open: an unreadable payload yields an empty id and
# falls through to arming, which is this hook's existing behaviour.
AID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)"
[ -z "$AID" ] || exit 0

# A RECOVERY-MANDATED READ IS NOT A HANDOFF INITIATION, AND THIS HOOK COULD NOT TELL THEM
# APART.
#
# `ai-dlc-recover.sh` MANDATES `Read <step file>` as the second tool call after EVERY
# compaction, and when a handoff is already pending it points that mandate at this very file.
# `ai-dlc-recover-gate.sh` then DENIES any other call until the Read happens. So a session
# that merely compacts while paused is compelled to read handoff.md — and this hook, which
# armed on any Read of that path unconditionally, wrote the entry marker on the strength of a
# Read the machinery itself forced.
#
# The marker means "this session is INSIDE the handoff procedure". Written from a compelled
# Read it means nothing of the kind, and it is key 1 of `ai_dlc_handoff_pending` — the key
# that arms the Stop guard and reroutes the NEXT compaction's mandate. Key 1 is self-clearing
# only in the sense that a COMPLETING handoff deletes it; a session that never began one has
# nothing to run step 5, so the marker persists and the guard blocks a Stop over a procedure
# that was never owed. That is the shape key 2 was given a lifecycle for one release earlier;
# this is the same defect at key 1, and neither file was touched by that change.
#
# THE FIX MUST NOT BREAK THE RECOVERY MANDATE, which is why this is a suppression on ONE
# distinguishable state and not a narrowing of the match. Recovery NEEDS that Read. What it
# does not need is the marker, and the two seeds that separate a correct fix from a broken one
# are: (1) a recovery-mandated Read, where arming is wrong, and (2) a genuine initiation Read
# with no recovery in flight, where arming is required. A fix keyed on anything else is
# byte-identical to a correct one on seed (1) and diverges only on seed (2).
#
# THE DISCRIMINATOR IS THE GATE'S OWN RECORD, read and never written here. `.recover-fired`
# exists from the moment `ai-dlc-recover.sh` injects until the mandated Reads are satisfied
# (the gate removes it) or the next `ai-dlc-postcompact.sh` consumes it. `step_file` inside it
# is the path the gate is DEMANDING. So the suppressed state is exactly: a recovery is in
# flight AND the file being read is the one that recovery named. Every other Read of
# handoff.md — including one taken during a recovery whose mandate pointed at a different
# step file — still arms, because that is a lead opening the procedure of its own accord.
#
# IT IS NOT `.recover-fired`, AND THAT WAS THE FIRST CUT'S DEFECT. Keying on the marker looks
# right and is UNREACHABLE: `ai-dlc-recover-gate.sh` is PreToolUse on every tool, this hook is
# PostToolUse on `Read`, and the gate DELETES the marker on the call that satisfies the second
# mandate. So by the time this hook runs, the file that would have answered is gone one hook
# earlier, the test falls through, and the marker is written from a Read the machinery forced.
# A seed that drives this hook alone with a hand-placed marker cannot see that: it reports
# not-armed, correctly, about a sequence no consumer ever executes.
#
# AND THE MARKER WOULD HAVE BEEN THE WRONG KEY EVEN IF IT SURVIVED. It says "a recovery is in
# flight", never "THIS Read is the one it demanded". A lead that satisfied only the FIRST
# mandated Read and then opened this file of its own accord is a GENUINE INITIATION with the
# marker still present, and keying on the marker suppresses it -- losing the routing, which is
# the worse direction by this hook's own reasoning.
#
# SO THE KEY IS THE GATE'S SATISFACTION BREADCRUMB, written by that gate on the satisfying
# call and ONLY there. It answers the narrow question this hook actually has: was this Read
# the one the recovery demanded. A recovery in flight that has NOT reached its second mandate
# writes no breadcrumb, so a voluntary open during that window still arms.
#
# READ AS KEY=VALUE, NEVER SOURCED. `.` on a file under the project directory would execute
# whatever a consumer's tree happened to put there; `ai-dlc-recover-gate.sh` reads its own
# state the same way and says so for the same reason.
#
# CONSUMED HERE. The breadcrumb describes ONE call, so leaving it on disk would let it answer
# for a later Read of the same file -- a voluntary re-open moments afterwards would be read as
# the mandated one and silently fail to arm. Removing it as it is read makes it one-shot on
# both sides; `ai-dlc-recover.sh` also clears it when a new recovery starts, so it cannot
# outlive the recovery that wrote it.
#
# FAIL OPEN TO ARMING. Every unreadable or ambiguous input falls through and writes the
# marker, which is this hook's existing behaviour. A marker written when it should not have
# been is a Stop guard the lead can clear with `rm`; a marker NOT written when the lead really
# is mid-handoff loses the routing this whole file exists to provide, and a compaction then
# sends the successor to the interrupted step instead of to the procedure.
_RS="${STATE_DIR}/.recover-satisfied"
if [ -f "$_RS" ]; then
  _RS_STEP="$(sed -n 's/^step_file=//p' "$_RS" 2>/dev/null | head -1)"
  rm -f "$_RS" 2>/dev/null || true
  if [ -n "$_RS_STEP" ]; then
    # Compare on the BASENAME UNDER ITS steps/ PARENT, the same grain the `case` above uses
    # and for the same reason: the mandate records a project-relative path while the Read may
    # arrive absolute or relative, and a whole-path compare would fail to suppress in exactly
    # the layouts this hook was written to span.
    case "$_RS_STEP" in
      */steps/handoff.md|steps/handoff.md)
        # The gate just recorded that THIS Read satisfied the second mandate. Not an initiation.
        exit 0 ;;
    esac
  fi
fi

# The output directory may legitimately not exist yet on a tree that has never run the
# pipeline; creating it here would manufacture pipeline state from a plain file read.
[ -d "$STATE_DIR" ] || exit 0
: > "${STATE_DIR}/.handoff-in-progress" 2>/dev/null || true
exit 0
