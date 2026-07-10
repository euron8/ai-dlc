#!/bin/bash
#
# AI/DLC PostCompact Hook
#
# Runs after a compaction completes, on both the `auto` and `manual` triggers,
# and receives the generated summary. Its output is display-only: PostCompact
# CANNOT inject context (only `userDisplayMessage` survives). It is therefore
# instrumentation, not recovery -- the recovery hook is ai-dlc-recover.sh.
#
# ORDERING. On Claude Code's compaction paths the SessionStart(compact) hooks run
# as part of rebuilding post-compact attachments, which happens BEFORE this hook
# fires. So by the time we run, ai-dlc-recover.sh has already left its marker,
# and we can record whether recovery context was actually injected.
#
# The log this writes is the standing evidence for the retro: how often
# compaction fired, on which trigger, and whether recovery ran each time.
#
# INSTALL
#   .claude/settings.json:
#     "PostCompact": [{ "matcher": "auto|manual",
#       "hooks": [{ "type": "command",
#                   "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-postcompact.sh" }] }]

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
SNAPSHOT="${STATE_DIR}/pipeline-snapshot.md"
LOG_FILE="${STATE_DIR}/compaction-log.md"
MARKER="${STATE_DIR}/.recover-fired"

INPUT="$(cat 2>/dev/null || true)"

[ -f "$SNAPSHOT" ] || exit 0

field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null
  fi
}

TRIGGER="$(field '.trigger')"
SUMMARY="$(field '.compact_summary')"
[ -n "$TRIGGER" ] || TRIGGER="unknown"

SUMMARY_BYTES="$(printf '%s' "$SUMMARY" | wc -c | tr -d ' ')"

# ai-dlc-recover.sh drops the marker when it injects. Consume it so the next
# compaction starts from a clean slate; a stale marker would over-report.
RECOVERED="no"
if [ -f "$MARKER" ]; then
  RECOVERED="yes"
  rm -f "$MARKER" 2>/dev/null || true
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true

if [ ! -s "$LOG_FILE" ]; then
  cat >"$LOG_FILE" <<'EOF'
# Compaction Log

Every conversation compaction during an AI/DLC sprint, written by
`.claude/hooks/ai-dlc-postcompact.sh`.

`recovery_injected: no` on an auto trigger means the lead resumed from the
summary alone -- the snapshot was never re-injected. That is the failure this
machinery exists to prevent; investigate before trusting the sprint's output.

Append-only. Rotates at sprint boundaries per Rule 25(c).

---
EOF
fi

{
  printf '\n## %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- trigger: %s\n' "$TRIGGER"
  printf -- '- recovery_injected: %s\n' "$RECOVERED"
  printf -- '- summary_bytes: %s\n' "${SUMMARY_BYTES:-0}"
  printf -- '- branch: %s\n' "$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo '(unknown)')"
} >>"$LOG_FILE" 2>/dev/null

if [ "$RECOVERED" = "yes" ]; then
  printf 'AI/DLC: compaction (%s); pipeline snapshot re-injected.\n' "$TRIGGER"
else
  printf 'AI/DLC: compaction (%s); snapshot NOT re-injected -- verify state before continuing.\n' "$TRIGGER"
fi

exit 0
