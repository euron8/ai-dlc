#!/bin/bash
#
# AI/DLC PreCompact Hook
#
# Runs immediately before Claude Code compacts the conversation, on both the
# `auto` and `manual` triggers. It does two things and blocks nothing.
#
# 1. STEERS THE SUMMARIZER. This hook's stdout becomes the compaction's
#    custom instructions. Claude Code REPLACES the instruction field with the
#    joined stdout of all succeeding PreCompact hooks -- so the incoming
#    `custom_instructions` must be echoed back, or a user's
#    `/compact <instructions>` is silently discarded.
#
# 2. FLUSHES A MECHANICAL SIDECAR. The pipeline snapshot is refreshed at gate
#    passages and sub-step boundaries, so at compaction time it can be up to one
#    sub-step stale. A shell script cannot make the lead write prose, but it can
#    capture the facts that moved: branch, commit, working tree, sprint status,
#    and the tail of the gate log. `ai-dlc-recover.sh` re-injects both files.
#
# WHY IT MUST NOT BLOCK. PreCompact supports blocking. Blocking a compaction
# that fired because the context is nearly full leaves the next stop at Claude
# Code's hard block (effectiveWindow - 3000), which is an unrecoverable API
# failure rather than a degraded turn. Steering only.
#
# INSTALL
#   .claude/settings.json:
#     "PreCompact": [{ "matcher": "auto|manual",
#       "hooks": [{ "type": "command",
#                   "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-precompact.sh" }] }]

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
SNAPSHOT="${STATE_DIR}/pipeline-snapshot.md"
SIDECAR="${STATE_DIR}/pipeline-snapshot.precompact.md"
GATE_LOG="${STATE_DIR}/implementation-artifacts/gate-log.md"
SPRINT_STATUS="${STATE_DIR}/implementation-artifacts/sprint-status.yaml"

INPUT="$(cat 2>/dev/null || true)"

# Arm only for an active pipeline. Same convention as ai-dlc-pause.sh and
# ai-dlc-continue.sh: no snapshot means no pipeline, so stay out of the way.
[ -f "$SNAPSHOT" ] || exit 0

# THE LEAD ONLY. A teammate runs in the same project dir, so it sees the same
# snapshot and the same settings.json -- the gate above does NOT exclude it. This
# hook TRUNCATES the lead's precompact sidecar (`>"$SIDECAR"`), so a teammate
# compacting would overwrite the lead's recovery net with its own delta: the lead
# would come back from ITS compaction reading a subagent's context as its own.
#
# Whether a teammate's compaction reaches PreCompact at all is not established --
# ai-dlc-subagent-probe.sh (SubagentStop) exists to measure exactly that. The
# gate is correct either way: a no-op if teammates never fire it, and the
# difference between a clean and a corrupted recovery if they do. ai-dlc-recover.sh
# and ai-dlc-context-sensor.sh already guard this way; precompact and postcompact
# did not, and nothing decided that asymmetry -- it was an omission.
if command -v jq >/dev/null 2>&1; then
  _AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
  [ -z "$_AGENT_ID" ] || exit 0
fi

field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null
  fi
}

TRIGGER="$(field '.trigger')"
CUSTOM="$(field '.custom_instructions')"
[ -n "$TRIGGER" ] || TRIGGER="unknown"

# -----------------------------------------------------------------------------
# 1. Mechanical sidecar. Overwritten each compaction, so it never accretes and
#    needs no Rule 25 rotation.
# -----------------------------------------------------------------------------
{
  printf '# Pre-Compact Sidecar\n\n'
  printf 'Mechanical state captured by `.claude/hooks/ai-dlc-precompact.sh`\n'
  printf 'immediately before compaction. Covers the delta since the snapshot'\''s\n'
  printf 'last sub-step write. Overwritten on every compaction.\n\n'
  printf -- '- captured_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- trigger: %s\n' "$TRIGGER"
  printf -- '- branch: %s\n' "$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo '(not a git repo)')"
  printf -- '- last_commit: %s\n' "$(git -C "$PROJECT_DIR" log -1 --oneline 2>/dev/null || echo '(none)')"
  printf '\n## Working tree (first 20 entries)\n\n```\n'
  git -C "$PROJECT_DIR" status --short 2>/dev/null | head -20
  printf '```\n'

  if [ -f "$SPRINT_STATUS" ]; then
    printf '\n## sprint-status.yaml\n\n```yaml\n'
    cat "$SPRINT_STATUS"
    printf '```\n'
  fi

  if [ -f "$GATE_LOG" ]; then
    printf '\n## gate-log.md (tail, 40 lines)\n\n```\n'
    tail -40 "$GATE_LOG"
    printf '```\n'
  fi
} >"$SIDECAR" 2>/dev/null

# -----------------------------------------------------------------------------
# 2. Summarizer steering. stdout -> compaction custom instructions.
#    Echo the user's instructions first; ours append, never replace.
# -----------------------------------------------------------------------------
if [ -n "$CUSTOM" ]; then
  printf '%s\n\n' "$CUSTOM"
fi

cat <<'EOF'
An AI/DLC pipeline is mid-sprint. The authoritative state lives on disk at
_bmad-output/pipeline-snapshot.md and is re-injected after compaction; do not
attempt to reconstruct it from the conversation. When summarizing, preserve
verbatim rather than paraphrasing:

- Every LOCKED_REQUIREMENTS entry and any Rule 11 user directive, exactly as worded.
- The current step file, the last gate passed, and any in-flight sub-step.
- Open adversarial findings and unresolved escalations, with their identifiers.
- Any decision the user accepted or rejected, and the stated reason.
- Exact error strings, failing test names, and file paths under discussion.

Discard freely: tool output already written to disk, file contents that can be
re-read, and narration of completed steps.
EOF

exit 0
