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
# WHAT IT DOES NOT DO. It does not police the THIRD mandated Read (`SKILL.md`), which the
# injected text asks for but which is a re-Read whose necessity this hook cannot establish
# from outside. It does not read the lead's prose, so the RECOVERY-SKIP disclosure the block
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

# --- what the injector recorded ----------------------------------------------------------
# Read as key=value lines, never sourced: `.` on a file in the project directory would execute
# whatever a consumer's tree happened to put there.
mval() { sed -n "s/^$1=//p" "$MARKER" 2>/dev/null | head -1; }

STEP_RESOLVED="$(mval step_file_resolved)"
SNAP_REL="$(mval snapshot_path)"
STEP_REL="$(mval step_file)"

# A marker written before this hook existed carries none of these keys. Treat that exactly as
# "cannot arm" -- an older marker is not evidence about a mandate it never recorded.
[ "$STEP_RESOLVED" = "1" ] || exit 0
[ -n "$SNAP_REL" ] || exit 0
[ -n "$STEP_REL" ] || exit 0

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

# Normalise the call's path the same way, so `Read _bmad-output/x.md` and an absolute form of
# the same file are one answer. A gate that matched only one spelling would deny a compliant
# call, which is a wedge wearing a different hat.
FABS=""
[ -n "$FPATH" ] && FABS="$(resolve "$FPATH")"

STAGE="$(cat "$PROGRESS" 2>/dev/null || printf 'snapshot')"

deny() {
  jq -n --arg reason "$1" --arg context "$2" \
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
      printf 'step\n' >"$PROGRESS" 2>/dev/null || true
      exit 0
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
      # SATISFIED. Clear both, so the gate is inert for the rest of the session until the
      # next compaction writes a fresh marker.
      rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true
      exit 0
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
