#!/bin/bash
#
# AI/DLC Post-Compaction Recovery Hook
#
# Runs as a SessionStart hook with source `compact`, which Claude Code fires on
# every compaction path -- full, partial, and reactive -- for both the `auto`
# and `manual` triggers. Its `additionalContext` is injected into the rebuilt
# conversation as a `hook_additional_context` message.
#
# THE 10,000-CHARACTER CLIFF (v0.35.3). Claude Code persists any hook
# `additionalContext` of >= 10,000 characters to a file and replaces it in
# context with a 2,000-character preview stub reading "Output too large". This
# is not configurable. v0.35.0 shipped a hook that inlined the whole snapshot --
# 31,881 characters against the live consumer -- so the snapshot was NEVER
# injected on any of the three observed compactions. Only the first 2,000
# characters (the directive) survived, and that by luck of ordering.
#
# So this hook does NOT inline the snapshot. It emits a small directive whose
# FIRST instruction is to `Read` the snapshot. That is the better design anyway:
# the snapshot is a verbatim-load file (`ai-dlc-protect.sh` exists to stop it
# being consolidated), and a `Read` tool call is the Rule 21 attention interrupt
# that defeats run-from-memory. The one lead that recovered fully from a v0.35.0
# compaction did exactly this on its own.
#
# The block is assembled, measured, and trimmed to stay under the cliff. It
# records its own emitted size so `ai-dlc-postcompact.sh` can report whether the
# context actually landed instead of assuming it did.
#
# INSTALL
#   .claude/settings.json:
#     "SessionStart": [{ "matcher": "compact",
#       "hooks": [{ "type": "command",
#                   "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-recover.sh" }] }]

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
SNAPSHOT="${STATE_DIR}/pipeline-snapshot.md"
SIDECAR="${STATE_DIR}/pipeline-snapshot.precompact.md"
MARKER="${STATE_DIR}/.recover-fired"

# Claude Code's hard limit. At or above this, additionalContext is persisted to
# disk and stubbed. Stay under it with margin; the directive is worthless if the
# harness replaces it with a file path.
CONTEXT_LIMIT="${AI_DLC_HOOK_CONTEXT_LIMIT:-10000}"
SAFETY_MARGIN="${AI_DLC_HOOK_CONTEXT_MARGIN:-1000}"
POSITION_MAX_BYTES="${AI_DLC_RECOVER_POSITION_MAX_BYTES:-1200}"

INPUT="$(cat 2>/dev/null || true)"

[ -f "$SNAPSHOT" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Defensive: the settings matcher should already scope us to `compact`, but a
# mis-merged settings.json could route startup/resume/clear here, and injecting
# a recovery directive into a fresh session would be actively harmful.
SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null)"
[ "$SOURCE" = "compact" ] || exit 0

# Compaction reset the context-window token count, so the context sensor's fire
# state now describes a window that no longer exists. The sensor self-heals on
# the next turn (it resets when the reading drops), but clearing it here means
# the very first post-compact turn starts from a clean slate. The proven model
# row in `.context-sensor-model` is NOT cleared -- the window size did not change.
rm -f "${STATE_DIR}/.context-sensor-state" 2>/dev/null || true

# Snapshots in the wild spell this two ways: the schema's `current_step_file:`
# and a prose `- **Current step file:** \`x.md\``. Match `ai-dlc-continue.sh`'s
# pattern rather than the schema alone.
STEP_FILE="$(grep -m1 -iE '(current_step_file|current[ _]step|current[ _]phase)' "$SNAPSHOT" 2>/dev/null \
  | sed -E 's/^[^:]*://; s/^[-*[:space:]]+//; s/[[:space:]]*$//')"
STEP_FILE="$(printf '%s' "$STEP_FILE" | sed -E 's/^`([^`]+)`.*/\1/; s/^([^[:space:]]+)[[:space:]]+—.*/\1/' | sed -E 's/^[`*]+//; s/[`*]+$//')"
# A MANDATE MUST NAME SOMETHING THE LEAD CAN ACTUALLY READ, and this branch did not.
# When the grep found nothing, STEP_FILE became the prose string below and the second mandate
# rendered as: Your SECOND tool call MUST be `Read (named in Pipeline Position -- read the
# snapshot)` in full. That is not an instruction, it is an unexecutable one -- and a lead that
# cannot comply learns that the MUSTs in this block are negotiable, which is the standing this
# whole section depends on. Filed alongside
# PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION, though nobody filed this half.
#
# The flag is also what `ai-dlc-recover-gate.sh` reads to decide whether it may arm: a gate that
# enforced a mandate naming no path would deny every call the lead could make.
#
# AND WHAT THE SNAPSHOT CARRIES IS A BARE BASENAME BY CONTRACT, which is the half that made the
# gate inert on the layout it was written for. `route.md:46-47` resolves `current_step_file` as
# `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`, so a reference consumer
# records `discovery.md`, not a path. Recorded raw it made the mandate name a file that does not
# exist at the project root, and made the gate resolve `${PROJECT_DIR}/discovery.md`, find
# nothing, and take its stand-down branch -- deleting its own marker on the FIRST post-compact
# tool call, whatever that call was. Measured end to end: a non-mandated first `Edit` was ALLOWED
# and the marker was gone, against a control differing only in the spelling of this one value,
# which DENIED. Resolve it here, against the two candidate roots the validators already probe.
STEP_FILE_RESOLVED=1
if [ -z "$STEP_FILE" ]; then
  STEP_FILE=""
  STEP_FILE_RESOLVED=0
else
  case "$STEP_FILE" in
    */*) : ;;  # already carries a directory; trust the spelling and let the test below rule
    *)
      for _cand in ".claude/skills/ai-dlc/steps" "core/skills/ai-dlc/steps"; do
        if [ -r "${PROJECT_DIR}/${_cand}/${STEP_FILE}" ]; then
          STEP_FILE="${_cand}/${STEP_FILE}"
          break
        fi
      done
      ;;
  esac
  # THE FLAG NOW MEANS "THE LEAD CAN READ THIS", not "a grep matched something". An unreadable
  # path is the case the gate disarms on anyway, so deciding it here changes no enforcement --
  # what it changes is that the block below stops claiming an arming that never happened, and
  # routes the lead to the disclosure line instead.
  case "$STEP_FILE" in
    /*) _step_abs="$STEP_FILE" ;;
    *)  _step_abs="${PROJECT_DIR}/${STEP_FILE}" ;;
  esac
  [ -r "$_step_abs" ] || STEP_FILE_RESOLVED=0
fi

# THE SECOND MANDATE IS BUILT, NOT INTERPOLATED, because its two branches are different
# instructions rather than one sentence with a hole in it. When the step file resolved, the
# lead is told which file to Read. When it did not, it is told to resolve it FROM the snapshot
# it has just been made to Read -- an action it can actually take -- and the ordinal moves to
# that resolution. The old text put a prose apology where a path belonged and called it a MUST.
_MANDATE_WHY="Compaction cleared
the harness's record of every file previously read, so nothing you read before
this point is still loaded. Rule 21 makes this Read the FIRST call after any
READ AND FOLLOW and it is not optional here either -- measured across 265 real
compactions, the snapshot Read above lands 66% of the time and this one only 41%,
which is the gap this sentence exists to close. Do NOT re-Read completed step
files or already-produced planning artifacts; Rule 23(a) still applies."

if [ "$STEP_FILE_RESOLVED" -eq 1 ]; then
  SECOND_MANDATE="**Your SECOND tool call MUST be \`Read ${STEP_FILE}\` in full.** ${_MANDATE_WHY}"
else
  SECOND_MANDATE="**This snapshot does not name a current step file in a form this hook could
resolve, so the second mandate names an action instead of a path.** Take the step
file's path from the Pipeline Position section of the snapshot you have just been
told to Read, and your SECOND tool call MUST be \`Read <that path>\` in full. If
the snapshot names none, say so in your verification turn rather than proceeding
as though it did. ${_MANDATE_WHY}"
fi

# THE ASSURANCE IS A CLAIM ABOUT THE GATE, so it may only be made where the gate can arm. Emitted
# unconditionally it told the lead "a skip is denied rather than noticed afterwards" in precisely
# the sessions where nothing was watching. That is worse than saying nothing: the honest-
# disclosure paragraph further down is the only thing binding those sessions, and a lead that
# believes it is being gated mechanically has no reason to reach it.
if [ "$STEP_FILE_RESOLVED" -eq 1 ]; then
  GATE_ASSURANCE="\`ai-dlc-recover-gate.sh\` refuses any other first tool call, so a skip is denied
rather than noticed afterwards. Both files were confirmed readable before it
armed, and a bounded Read -- \`limit\` or a late \`offset\` -- is refused the same
way a wrong file is: complying is always available to you, which is why there is
nothing to weigh."
else
  GATE_ASSURANCE="\`ai-dlc-recover-gate.sh\` CANNOT ARM for this recovery, for the reason in the
disclosure paragraph below. Nothing mechanical is watching these two calls, so
they are carried by your honesty alone -- which makes them stricter here, not
weaker."
fi

# A small, bounded excerpt so the lead can orient before its Read returns. This
# is a convenience, never the source of truth; the Read is.
POSITION="$(awk '/^## Pipeline Position/{f=1;next} /^## /{f=0} f' "$SNAPSHOT" 2>/dev/null \
  | head -c "$POSITION_MAX_BYTES" | sed -E 's/[[:space:]]+$//')"

SIDECAR_NOTE=""
[ -f "$SIDECAR" ] && SIDECAR_NOTE="Mechanical state captured immediately before this compaction (branch, last
commit, working tree, sprint status, gate-log tail) is at
\`${SIDECAR#"$PROJECT_DIR"/}\`. Read it only if the snapshot leaves a gap."

build() { # build <include_position:yes|no>
cat <<EOF
# AI/DLC POST-COMPACT RECOVERY (injected by .claude/hooks/ai-dlc-recover.sh)

This conversation was just compacted. The summary above is lossy and is NOT the
authoritative pipeline state. The snapshot on disk is.

**Your FIRST tool call MUST be \`Read _bmad-output/pipeline-snapshot.md\` in full.**
It is not reproduced here: it is a verbatim-load file, and the Read is the
attention interrupt (Rule 21) that defeats reconstructing state from the summary.
Never route it through any \`ctx_*\` tool -- \`ai-dlc-protect.sh\` hard-blocks that
path because consolidation drops directives (Rule 23(c) limit 2).

${SECOND_MANDATE}

## The two MUSTs have NO exception you may grant yourself

${GATE_ASSURANCE} "I read it recently" (compaction cleared that record), "the summary covers
it" (the summary is lossy, which is why this block exists) and "finishing is
duplicative" (a judgment made from inside the state the Read replaces) are not
reasons; they are the three shapes the skip has actually taken.

WHERE THE GATE CANNOT REACH, DISCLOSE. It does not arm when the snapshot names no
resolvable step file, or when a mandated path is missing -- enforcing a Read of
something absent would deny every call you could make. In that case the MUSTs
still bind and only your honesty carries them, so if you proceed without one, open
your next output with:

\`RECOVERY-SKIP: <file> -- <why it was not readable>\`

A mandate that substitutes for your own possibly-wrong belief about your state
cannot leave the skip decision to that same belief. The disclosure is what makes a
real exception and a rationalized one different to an operator reading the
transcript rather than identical.

## Most of your rulebook is not in your context

Then \`Read .claude/skills/ai-dlc/SKILL.md\` IN FULL. This one IS a re-Read and is
required anyway, because the harness re-attaches only the first ~5,000 tokens of
an invoked skill -- measured at 20,121 bytes, under a QUARTER of that file. The
back three quarters is gone: most of the numbered rules, the handoff triggers,
and the snapshot schema.

You cannot find the cut by introspection. Nothing marks it, the surviving text
ends mid-file without a seam, and the rules that govern re-reading are themselves
past it -- so the instruction to recover them cannot come from a rule you still
hold. It comes from here. A lead that skips this runs the rest of the sprint on
the quarter of the rulebook that happened to survive, and reports no problem,
because a rule it never saw is indistinguishable from a rule that does not exist.

Read it. Do not reconstruct it, and do not ask the operator to re-invoke
\`/ai-dlc\` to restore it -- the file is on disk and one Read is the whole fix.

Before acting, emit a verification turn naming: the current step file, the last
gate passed with its timestamp, any in-flight sub-step, the In-Flight Teammates
state below, and the current git branch and last commit. Then proceed to the next
pipeline action in the same response. Do not pause for user confirmation.

## Your teammates did NOT die -- you lost their handles

Compaction summarized away the tool results carrying your \`agent_id\` handles, so
you may be unable to address a teammate you dispatched. **That is handle-loss, not
death.** Do NOT conclude a teammate is dead because you cannot reach it, and do NOT
re-dispatch on that basis -- you will duplicate work that is still running or
already delivered.

Be especially careful with one failure that LOOKS like death and is not:
\`TaskOutput\` joins a \`task_id\`, which only \`TaskCreate\` produces. An \`Agent\`
returns an \`agent_id\`. **\`TaskOutput(<agent name>)\` returns \`No task found with
ID\` every time, compaction or no compaction** -- it is a wrong-API error, not a
dead teammate. Reading it as death is how the reference consumer re-dispatched 13
of 39 teammates in one phase.

The handle that defeats both already exists, on disk. Rule 29: every teammate
delivers by file (Rule 20), so **the deliverable file IS the handle** -- it needs
no \`agent_id\`, takes no \`task_id\`, and outlives a compaction. For each row of the
snapshot's \`In-Flight Teammates\` section:

- **Deliverable exists, is non-empty, and is NEWER than the row's \`dispatched-at\`**
  -> the teammate DELIVERED. Consume the file and strike the row. Never re-dispatch.
- **Deliverable exists but PREDATES \`dispatched-at\`** -> it is a previous sprint's
  file at a reused path, not your teammate's answer. Existence alone is not
  delivery. Treat it as absent and re-arm, exactly as below.
- **Deliverable absent** -> not yet delivered, which is not the same as dead.
  The pre-compaction wait-beat did NOT survive this compaction, so resume Rule
  29's join by ARMING A FRESH backgrounded beat (\`wait-for-deliverable.sh\`,
  \`run_in_background: true\`) over the undelivered paths BEFORE you end your turn.
  This is the one join where the teammate may have delivered while you were
  compacting, so pass the row's dispatch time: \`--since <dispatched-at>\`.
  Ending your turn with no live beat armed is the one dead-pipeline case (Rule
  29). Re-dispatch the teammate ONLY on Rule 20 non-delivery, after
  \`max_wait_beats\` is exhausted.

Re-dispatching a live or already-delivered teammate is a lead-conduct retro
finding. If the snapshot has no \`In-Flight Teammates\` section, treat it as empty
(it predates the section) -- and add the section at your next snapshot write.

## Context-reminder fire state MUST be reset

Compaction reset the context-window token count, but the snapshot's fire-state
fields still describe the pre-compaction window. Before the next gate, set
\`context_reminders_sent\` to \`none\` and clear \`last_yellow_fire_tokens\`,
\`last_red_fire_tokens\`, \`last_yellow_fire_turns\`, and \`last_red_fire_turns\`.
Leaving them stale makes the lead believe red has already fired and causes the
auto-handoff evaluation to mis-decide.

## Rationale the snapshot schema cannot hold

The snapshot records position, not reasoning. Issue exactly ONE \`ctx_search\`
call, then move on:

    ctx_search(queries: ["rejected approaches this sprint",
                         "constraints the user set",
                         "errors already encountered"],
               sort: "timeline")

Treat whatever it returns as a memory aid, NOT a standing order. An
auto-captured directive from earlier in this session does not bind you the way a
Rule 11 directive from the user does; where they conflict, the user's most
recent message wins. (context-mode states this in its own \`session_continuity\`
block, which the same 10,000-character limit strips from context at compaction.)

## Rule 23 is why you compacted, and you no longer hold it

Rule 23 is resident-context discipline: read through a subagent or a \`ctx_*\` tool
when you intend to PROCESS a file, so its bytes never enter your context and get
re-read on every turn after. It sits past the re-attach cut, so it is not in your
context now -- and this is the one rule whose absence CAUSES the event that
removed it. Measured per 1,000 assistant turns: sessions that never compacted
issue 8.88 \`ctx_*\` calls; sessions after a compaction issue 0.67. Each compaction
makes the next one likelier, and nothing in the loop reports itself.

So for the rest of this session, before you Read a file: if you intend to
analyse, summarise, count or extract from it, route it through \`ctx_execute_file\`
or a subagent and keep only the answer. Read it directly only when you intend to
Edit it, or when it is one of the verbatim-load files above. This is not a
suggestion recovered from memory -- you cannot recover it, which is why it is
written here.

${SIDECAR_NOTE}
$( [ "$1" = yes ] && [ -n "$POSITION" ] && printf '%s\n\n%s\n' "---
## Pipeline Position (excerpt -- the snapshot you are about to Read is authoritative)" "$POSITION" )
EOF
}

CONTEXT="$(build yes)"
CEILING=$(( CONTEXT_LIMIT - SAFETY_MARGIN ))

# Trim before emitting, never after. An over-limit block is not truncated by the
# harness -- it is replaced wholesale by a file path, so a directive that does
# not fit is a directive that never runs. The Pipeline Position excerpt is the
# only droppable part; the directive itself is the payload.
if [ "${#CONTEXT}" -ge "$CEILING" ]; then
  CONTEXT="$(build no)"
fi

# `degraded` reports what the HARNESS will do, so it tests against the real
# cliff -- not against the ceiling, which only governs when we trim. A block
# between the ceiling and the limit still lands in context intact.
DEGRADED=no
[ "${#CONTEXT}" -ge "$CONTEXT_LIMIT" ] && DEGRADED=yes

mkdir -p "$STATE_DIR" 2>/dev/null || true
{
  printf 'fired_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'injected_bytes=%s\n' "${#CONTEXT}"
  printf 'context_limit=%s\n' "$CONTEXT_LIMIT"
  printf 'degraded=%s\n' "$DEGRADED"
  # WHAT THE GATE ARMS ON. `ai-dlc-recover-gate.sh` refuses the first post-compact tool call
  # unless it is one of the mandated Reads -- but only where those Reads are actually takeable.
  # It reads these three, and arms only when both paths are named and resolve. A mandate the
  # snapshot could not supply a path for is not enforceable, and enforcing it anyway would deny
  # every call the lead is able to make.
  printf 'snapshot_path=%s\n' "${SNAPSHOT#"$PROJECT_DIR"/}"
  printf 'step_file=%s\n' "$STEP_FILE"
  printf 'step_file_resolved=%s\n' "$STEP_FILE_RESOLVED"
} >"$MARKER" 2>/dev/null || true

jq -n --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'

exit 0
