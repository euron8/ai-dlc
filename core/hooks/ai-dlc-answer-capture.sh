#!/bin/bash
#
# AI/DLC Operator Answer Capture Hook
#
# PURPOSE
# Records what the operator SELECTED at an AskUserQuestion, to disk, before any
# agent writes prose about it. The sibling hook `ai-dlc-pause.sh` does this for
# typed prose on UserPromptSubmit; an AskUserQuestion answer never raises that
# event, so the one class of operator decision the pipeline solicits deliberately
# was the one class no artifact held.
#
# WHY A HOOK AND NOT A TRANSCRIPT READ. The obvious design -- have the lead quote
# the answer, and verify the quote against the session transcript -- was built as a
# probe and measured, and it is dead. At the moment PostToolUse fires, the transcript
# does NOT yet carry the answers record: a `tail` of the live transcript at hook time
# returns zero matches, while the same pattern over the whole file afterwards returns
# two. The zero is timing, not absence. A hook that read the answer from the transcript
# would find nothing and would have to either fail or invent.
#
# The answer IS in this hook's own payload, and cleanly. For `tool_name`
# `AskUserQuestion`, `.tool_response` is an object carrying `annotations`,
# `questions` and `answers`, and `.tool_response.answers` is a `{question: answer}`
# map identical to the `toolUseResult.answers` the transcript records later. So the
# hook reads its own payload and writes the answer down.
#
# WHAT IS HASHED, AND WHY ONLY THAT. Each record's fenced body and its `SHA256:` cover
# the ANSWER ALONE. The QUESTION is text the LEAD authored, and it is stored on a
# labelled metadata line that no hash covers, because a lead permitted to cite words it
# wrote itself passes a provenance check by talking to itself -- the S290 fabrication,
# reintroduced through the fix for its mirror image. `validate-steering-budget.sh`'s
# `askUserQuestionAnswers` extractor makes exactly the same split for exactly this
# reason, and returns only the answer side of each pair. A body written here is
# therefore independently citable against the session transcript with
#
#     validate-steering-budget.sh --dir <transcript-dir> --cite "<the answer body>"
#
# which is what makes the SHA a citation grade rather than a checksum: the hash
# resolves to a hook-written record, and that record's body can be shown to be the
# operator's own selection.
#
# ONE RECORD PER ANSWER, not per tool call. A single AskUserQuestion may carry up to
# four questions. A record spanning all of them would have one hash covering several
# independent decisions, and a field citing that hash would name all of them at once.
# Each question/answer pair gets its own `## ` block and its own SHA so a snapshot
# field can cite exactly one decision.
#
# APPEND-ONLY, structurally. The filename ends `-history.md`, which is the predicate
# `validate-artifact-budget.sh`'s is_archive() reads: no budget row, no rotation, no
# trim. A provenance record that can be evicted to fit a budget is not a provenance
# record.
#
# NEVER BLOCKS. This hook observes; it has no verdict. Every path exits 0, including
# every failure path -- a capture hook that can fail a tool call would make the
# pipeline's ability to ask a question depend on its ability to write a file.
#
# IT ALSO ROUTES, AND THAT IS NOT THE SAME AS BLOCKING. Recording the answer was never
# enough. Measured on the reference consumer: the lead asked an AskUserQuestion about a
# gate disposition, the operator answered "handoff", and the lead read the intent correctly
# and then improvised -- one TaskStop, a snapshot edit, a touched pause flag -- without
# ever loading steps/handoff.md in that session. No full teammate sweep, no commit, no push
# attempt, no resume line. `ai-dlc-pause.sh` was the ONLY thing in the system that routes a
# handoff request, and it fires on UserPromptSubmit, which an AskUserQuestion answer never
# raises. The continuation log recorded no USER_PAUSE across the whole episode; the
# ALLOWED_BY_PAUSE that appears in it reads a flag the lead created itself.
#
# So on an answer carrying handoff intent this hook now does what the sibling hook does on
# a typed request: creates the pause flag, logs USER_PAUSE, and emits the routing block as
# PostToolUse additionalContext. A PostToolUse hook may emit additionalContext without
# blocking -- the tool call has already returned -- so the NEVER BLOCKS contract above is
# unchanged, and every path below still exits 0.
#
# NEITHER THE BRANCH TEXT NOR THE VOCABULARY IS WRITTEN HERE. Both are declared once in
# schemas/pause-routing.json and read by this hook, by ai-dlc-pause.sh, and by
# ai-dlc-continue.sh's Check 0. ai-dlc-pause.sh's own header had already ruled on what to
# do when a second reader appears -- single-source it, do not copy it -- and a second
# hand-maintained list of handoff phrasings is exactly the drift that ruling exists to
# prevent.
#
# OUTPUT
# - Appends to: _bmad-output/operator-answers-history.md
# - On handoff intent only: creates _bmad-output/pipeline-paused.flag, appends USER_PAUSE
#   to _bmad-output/pipeline-continuation-log.md, and writes the routing JSON to stdout
# - stdout: nothing on every other path
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-answer-capture.sh
# 2. chmod +x .claude/hooks/ai-dlc-answer-capture.sh
# 3. Add to .claude/settings.json hooks:
#      "PostToolUse": [
#        {
#          "matcher": "AskUserQuestion",
#          "hooks": [{
#            "type": "command",
#            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-answer-capture.sh"
#          }]
#        }
#      ]
# 4. Restart Claude Code
# 5. Verify with /hooks

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
LOG_DIR="${PROJECT_DIR}/_bmad-output"
ANSWERS_FILE="${LOG_DIR}/operator-answers-history.md"
LOG_FILE="${LOG_DIR}/pipeline-continuation-log.md"
PAUSE_FLAG="${LOG_DIR}/pipeline-paused.flag"
SNAPSHOT_FILE="${LOG_DIR}/pipeline-snapshot.md"

# The routing declaration. `../schemas/` resolves in BOTH layouts from a hook -- core/hooks/
# upstream, .claude/hooks/ in a consumer -- and is the copy that shipped in the same package
# as this file. The PROJECT_DIR candidates are the fallback for a hook invoked through a
# copy; the env override is for fixtures driving this hook from a temp directory.
_prs_self="$(cd "$(dirname "$0")" && pwd)"
PAUSE_ROUTING_SCHEMA=""
for _prs in "${AI_DLC_PAUSE_ROUTING_SCHEMA:-}" \
            "${_prs_self}/../schemas/pause-routing.json" \
            "${PROJECT_DIR}/.claude/schemas/pause-routing.json" \
            "${PROJECT_DIR}/core/schemas/pause-routing.json"; do
  [ -n "$_prs" ] && [ -f "$_prs" ] && { PAUSE_ROUTING_SCHEMA="$_prs"; break; }
done

INPUT=$(cat)

# jq is required to read the payload at all. Absent it, exit quietly rather than
# writing a partial or malformed record -- a missing entry is a gap a later check can
# count, and `scope_confirmed_cite: none` is an honest value. A corrupt entry is not.
command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME=$(jq -r '.tool_name // empty' <<<"$INPUT" 2>/dev/null)
[ "$TOOL_NAME" = "AskUserQuestion" ] || exit 0

SESSION_ID=$(jq -r '.session_id // empty' <<<"$INPUT" 2>/dev/null)
TOOL_USE_ID=$(jq -r '.tool_use_id // empty' <<<"$INPUT" 2>/dev/null)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# `.tool_response.answers` is the {question: answer} map. Emit one TSV line per pair
# with the answer's newlines escaped, so a multi-line answer stays one record here and
# is restored below. `to_entries` on a null or absent field yields nothing, so a
# payload without answers -- a dismissed prompt, a shape change in a later harness --
# produces no records rather than an empty one.
PAIRS=$(jq -r '
  (.tool_response.answers // {})
  | to_entries[]
  | [(.key // ""), (.value // "")]
  | @tsv
' <<<"$INPUT" 2>/dev/null)

[ -n "$PAIRS" ] || exit 0

mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

if [ ! -s "$ANSWERS_FILE" ]; then
  cat > "$ANSWERS_FILE" <<'EOF'
# Operator Answers

Every AskUserQuestion answer an operator selected, recorded by the PostToolUse hook
from the hook's own payload. Append-only. Written by `ai-dlc-answer-capture.sh`; no
agent may edit or reorder it.

This file exists because an AskUserQuestion answer never raises UserPromptSubmit, so
the sibling capture in `ai-dlc-pause.sh` structurally cannot see it. The operator's
selections -- including every pipeline decision the lead deliberately stopped to ask
for -- lived only in the transcript, and a field claiming one was a lead's account of
a choice with nothing able to contradict it.

**The `SHA256:` and the fenced body cover the ANSWER ONLY.** The `Question:` line is
text the LEAD authored and no hash covers it. Citing your own question back at a
provenance check is not evidence, which is why `validate-steering-budget.sh` returns
only the answer side of each pair. Verify any entry with:

    validate-steering-budget.sh --dir <transcript-dir> --cite "<a phrase from body>"

One entry per question/answer pair, never per tool call: a single AskUserQuestion may
ask up to four independent questions, and one hash over all of them could not cite
any one of them.

Rotation: none, ever. The filename ends `-history.md` so the artifact-budget validator
treats it as an archive (Rule 25(a)): growth is free, and nothing may trim it.

---

EOF
fi

# The handoff-intent vocabulary, resolved from the declaration. Both halves are required:
# the intent pattern alone fires on an answer that DISCUSSES the handoff mechanism, and the
# exclusion is the veto that stops it. An unresolved declaration leaves both empty and the
# routing arm below stands down -- see its own comment for why that silence is covered by a
# fixture rather than by a fallback copy of the list.
HANDOFF_INTENT_RE=""
HANDOFF_MENTION_RE=""
if [ -n "$PAUSE_ROUTING_SCHEMA" ]; then
  HANDOFF_INTENT_RE="$(jq -rj '.handoff_intent_pattern // ""' "$PAUSE_ROUTING_SCHEMA" 2>/dev/null)"
  HANDOFF_MENTION_RE="$(jq -rj '.handoff_mention_exclusion_pattern // ""' "$PAUSE_ROUTING_SCHEMA" 2>/dev/null)"
fi
HANDOFF_ANSWER=""
HANDOFF_QUESTION=""

# Read the TSV with a plain `read`, splitting on tab only. IFS is set per-read so the
# surrounding shell keeps its own.
#
# THE LOOP IS FED BY A HERE-STRING, NOT A PIPE, which is what lets HANDOFF_ANSWER survive
# it. A pipe would run the loop in a subshell and every assignment made below would be
# discarded at `done`, leaving the routing arm permanently unreachable and looking exactly
# like an operator who never asked for a handoff.
while IFS=$'\t' read -r Q_ESC A_ESC; do
  [ -n "${A_ESC:-}" ] || continue
  # Restore the escaped newlines jq wrote. `printf %b` expands \n and \t.
  ANSWER=$(printf '%b' "$A_ESC")
  QUESTION=$(printf '%b' "${Q_ESC:-}" | tr '\n' ' ')
  # An answer that is only whitespace carries no decision.
  [ -n "$(tr -d '[:space:]' <<<"$ANSWER")" ] || continue
  # Handoff intent is read from the ANSWER, never from the question. The question is text
  # the LEAD authored -- "should I hand off or keep going?" carries the phrasing and none of
  # the intent -- so matching on it would route on the lead's own words and pause the
  # pipeline on every question that mentions the option.
  # MATCHED ON ONE LINE. The declared patterns anchor on `^` and `$`, and grep anchors per
  # line, so a multi-line answer with a middle line reading `handoff` matched on that line
  # alone and paused the pipeline. The record below keeps the answer's newlines; only the
  # match sees them collapsed -- the same shape ai-dlc-pause.sh writes for key 3's reader.
  ANSWER_FLAT=$(tr '\n' ' ' <<<"$ANSWER")
  if [ -z "$HANDOFF_ANSWER" ] && [ -n "$HANDOFF_INTENT_RE" ] && [ -n "$HANDOFF_MENTION_RE" ] \
     && grep -qiE "$HANDOFF_INTENT_RE" <<<"$ANSWER_FLAT" \
     && ! grep -qiE "$HANDOFF_MENTION_RE" <<<"$ANSWER_FLAT"; then
    HANDOFF_ANSWER="$ANSWER"
    HANDOFF_QUESTION="$QUESTION"
  fi
  ANS_SHA=$(printf '%s' "$ANSWER" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)
  {
    echo "## ${TIMESTAMP} -- AskUserQuestion"
    echo "- Session: ${SESSION_ID}"
    echo "- Tool-use: ${TOOL_USE_ID}"
    echo "- Question (lead-authored, NOT covered by the hash): ${QUESTION}"
    echo "- Bytes: $(printf '%s' "$ANSWER" | wc -c | tr -d '[:space:]')"
    echo "- SHA256: ${ANS_SHA}"
    echo ""
    echo '```text'
    printf '%s\n' "$ANSWER"
    echo '```'
    echo ""
  } >> "$ANSWERS_FILE"
done <<<"$PAIRS"

# -----------------------------------------------------------------------------
# Route a handoff that arrived as an answer
# -----------------------------------------------------------------------------
# NOTHING BELOW THIS LINE MAY FAIL THE TOOL CALL. The capture above is the part that must
# always happen; this arm is additive, and every path through it ends at `exit 0`.
[ -n "$HANDOFF_ANSWER" ] || exit 0

# GATED ON AN ACTIVE PIPELINE, the same gate ai-dlc-pause.sh uses and for the same reason:
# without a snapshot there is no pipeline to pause, and a flag file dropped into a
# non-AI/DLC session is litter the lead will not know to clear. Unlike that hook, the
# CAPTURE has already happened -- it is deliberately not gated -- so nothing is lost here.
[ -f "$SNAPSHOT_FILE" ] || exit 0

touch "$PAUSE_FLAG" 2>/dev/null || exit 0

# Seed the log header if this is the first write, byte-identically to every other hook that
# opens this file. `pipeline-continuation-log.md` is opened by whichever hook fires first,
# each seeding its own copy, and which legend a sprint gets is therefore decided by firing
# order -- so retro.md §4b, which counts events out of this log and reads the legend as the
# definition of what a count MEANS, would get a different definition depending on nothing.
# core/fixtures/pause-hook-origin assertion 8 compares every seeding hook's copy and fails
# the push if any one of them drifts; this file is one of the copies it compares.
if [ ! -s "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<'EOF'
# Pipeline Flow Log

Records pipeline-level events: user pauses, Rule 3 enforcement, operator
acknowledgement denials, and rapid-fire stall detection. Generated by AI/DLC
hook scripts. Rotated per sprint at retro close (Rule 25(c)).

Event types:

- `USER_PAUSE`: the operator steered and the pipeline paused via flag file. TWO
  channels raise it and the entry's `Channel:` line names which: a typed message
  (UserPromptSubmit), or an AskUserQuestion answer carrying handoff intent. The
  second raises no UserPromptSubmit at all, so before it was routed a handoff
  asked for that way produced no USER_PAUSE, no flag, and no record that the
  operator had spoken
- `PAUSE_SKIPPED`: a UserPromptSubmit carried no operator prose, so no pause
  flag was created. The harness raises the event identically for a completed
  background task and for a human typing; this records the ones that were not
  a human, so a pause that never happened is distinguishable from one the lead
  already cleared
- `BLOCKED`: Stop event blocked; Rule 3 enforcement forced continue
- `ALLOWED_BY_PAUSE`: Stop event allowed because pause flag exists
- `ACK_DENIED`: a pipeline-advancing tool call was DENIED because an operator
  message was outstanding and unacknowledged (Rule 29). A nonzero count means
  the lead tried to execute straight through a waiting human and the hook --
  not the lead's judgment -- is what stopped it. Investigate each one.
- `BACKOFF`: rapid-fire stop attempts detected; stall confirmed
- `ESCALATION_UNDELIVERED`: a SendMessage returned `success:false`, so an
  operator-bound message was never delivered. The harness does NOT mark these
  as tool errors, which is why they fell through silently; a nonzero count
  means an escalation the lead believed it had sent did not arrive. Read the
  recorded target -- a failure to reach `parent` is subagent routing, not an
  operator escalation

Retro reviews this log to assess pipeline flow:

- High USER_PAUSE counts mean the user intervened often (normal for
  interactive sprints, concerning if unexpected)
- High PAUSE_SKIPPED counts are normal in a sprint with heavy background
  dispatch; a SUDDEN change in the USER_PAUSE:PAUSE_SKIPPED ratio is the
  signal worth reading
- High BLOCKED counts mean Rule 3 enforcement is doing work; without
  the hook the pipeline would have stalled
- BACKOFF entries indicate the pipeline actually got stuck and the
  hook exhausted its retry budget. Investigate the transcript around
  each BACKOFF to find the upstream cause.

Counting entries: one event is one `## <timestamp> -- <EVENT>` line. Count with
`grep -c '^## .*-- <EVENT>'`. A bare `grep -c <EVENT>` also matches this header,
which mentions every event name, so it over-reports — and the inflated number is
plausible enough that nothing about the result signals it counted documentation.

---

EOF
fi

{
  echo "## ${TIMESTAMP} -- USER_PAUSE"
  echo "- Session: ${SESSION_ID}"
  echo "- Channel: AskUserQuestion answer (handoff intent)"
  echo "- Tool-use: ${TOOL_USE_ID}"
  echo "- Question (lead-authored, NOT the intent signal): $(printf '%s' "$HANDOFF_QUESTION" | head -c 120)"
  echo "- Answer (first 120 chars): $(printf '%s' "$HANDOFF_ANSWER" | tr '\n' ' ' | head -c 120)"
  echo ""
} >> "$LOG_FILE"

# The routing block. Preamble and branch text both come from the declaration; a partial
# instruction is worse than none, so an unreadable one emits nothing. The pause flag and the
# USER_PAUSE record above still stand -- the lead will meet the flag at its next Stop even
# if this context never arrives.
ROUTE_CONTEXT="$(jq -rj '(.answer_pause_preamble // "") + (.pause_branch_text // "")' \
                 "$PAUSE_ROUTING_SCHEMA" 2>/dev/null)"
[ -n "$ROUTE_CONTEXT" ] || exit 0

# PROVENANCE MARKER -- PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL. The
# library is a SIBLING in both layouts (core/hooks/, .claude/hooks/), so this is a
# same-directory read and never a walk up from a resolved path. Fail-open: a hook
# that cannot mark its output still emits it.
_AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi

jq -n --arg context "$(ai_dlc_provenance_wrap ai-dlc-answer-capture PostToolUse "$ROUTE_CONTEXT")" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $context
  }
}' 2>/dev/null || true

exit 0
