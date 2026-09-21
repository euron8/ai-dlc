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
# the arming decision below, keyed on the gate's own in-flight record.
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

case "$FPATH" in
  */steps/handoff.md) : ;;
  *) exit 0 ;;
esac

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
# READ AS KEY=VALUE, NEVER SOURCED. `.` on a file under the project directory would execute
# whatever a consumer's tree happened to put there; `ai-dlc-recover-gate.sh` reads the same
# file the same way and says so for the same reason.
#
# FAIL OPEN TO ARMING. Every unreadable or ambiguous input falls through and writes the
# marker, which is this hook's existing behaviour. A marker written when it should not have
# been is a Stop guard the lead can clear with `rm`; a marker NOT written when the lead really
# is mid-handoff loses the routing this whole file exists to provide, and a compaction then
# sends the successor to the interrupted step instead of to the procedure.
_RF="${STATE_DIR}/.recover-fired"
if [ -f "$_RF" ]; then
  _RF_STEP="$(sed -n 's/^step_file=//p' "$_RF" 2>/dev/null | head -1)"
  if [ -n "$_RF_STEP" ]; then
    # Compare on the BASENAME UNDER ITS steps/ PARENT, the same grain the `case` above uses
    # and for the same reason: the mandate records a project-relative path while the Read may
    # arrive absolute or relative, and a whole-path compare would fail to suppress in exactly
    # the layouts this hook was written to span.
    case "$_RF_STEP" in
      */steps/handoff.md|steps/handoff.md)
        # A recovery is in flight and IT is what demanded this Read. Not an initiation.
        exit 0 ;;
    esac
  fi
fi

# The output directory may legitimately not exist yet on a tree that has never run the
# pipeline; creating it here would manufacture pipeline state from a plain file read.
[ -d "$STATE_DIR" ] || exit 0
: > "${STATE_DIR}/.handoff-in-progress" 2>/dev/null || true
exit 0
