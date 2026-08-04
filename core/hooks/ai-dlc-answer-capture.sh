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
# OUTPUT
# - Appends to: _bmad-output/operator-answers-history.md
# - stdout: nothing
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

# Read the TSV with a plain `read`, splitting on tab only. IFS is set per-read so the
# surrounding shell keeps its own.
while IFS=$'\t' read -r Q_ESC A_ESC; do
  [ -n "${A_ESC:-}" ] || continue
  # Restore the escaped newlines jq wrote. `printf %b` expands \n and \t.
  ANSWER=$(printf '%b' "$A_ESC")
  QUESTION=$(printf '%b' "${Q_ESC:-}" | tr '\n' ' ')
  # An answer that is only whitespace carries no decision.
  [ -n "$(tr -d '[:space:]' <<<"$ANSWER")" ] || continue
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

exit 0
