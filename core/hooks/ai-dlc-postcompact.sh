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

# THE LEAD ONLY -- same reasoning as ai-dlc-precompact.sh. A teammate shares the
# project dir, so the snapshot gate does not exclude it. This hook appends to
# compaction-log.md, which is the retro's standing evidence for "how often did
# the LEAD compact"; a teammate's compaction landing in that log silently inflates
# the count and would send a retro hunting a lead problem that never happened.
if command -v jq >/dev/null 2>&1; then
  _AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
  [ -z "$_AGENT_ID" ] || exit 0
fi

# AN UPDATE SESSION'S COMPACTION IS NOT THE LEAD'S, so it is neither logged nor announced.
# ai-dlc-recover.sh stands down for /ai-dlc-update and writes no marker; without the same
# stand-down here this hook read that absence as "recovery hook did not fire", logged
# `recovery_injected: no` -- which retro.md reads as a lead that resumed from the summary
# alone -- and printed the warning into the updater. With a lead's marker still on disk it
# logged `yes` with the lead's byte count instead. The question is the I126 scan, one line
# shared with the hooks that already ask it; an unreadable or absent transcript leaves the
# hook as it was.
_EV_SID=""; _EV_TP=""
if command -v jq >/dev/null 2>&1; then
  _EV_P="$(printf '%s' "$INPUT" | jq -r '@sh "_EV_SID=\((.session_id // "") | tostring) _EV_TP=\((.transcript_path // "") | tostring)"' 2>/dev/null)" && eval "$_EV_P"
fi
if [ -n "$_EV_TP" ] && [ -r "$_EV_TP" ]; then
  TRANSCRIPT="$_EV_TP"
  # >>> I126 SESSION-MARKER SCAN: the next line, byte-identical in every bound hook >>>
  LAST_SKILL=$(grep -oE '"role":"user","content":"<command-message>ai-dlc(-update)?</command-message>\\n<command-name>/ai-dlc(-update)?</command-name>|"name":"Skill","input":\{"skill":"ai-dlc(-update)?"' "$TRANSCRIPT" 2>/dev/null | tail -1)
  case "$LAST_SKILL" in
    *'/ai-dlc-update</command-name>'|*'"skill":"ai-dlc-update"') exit 0 ;;
  esac
fi

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
#
# The marker carries the size recover.sh actually emitted. Reporting "yes" on
# mere marker presence is what made v0.35.0's log lie: the hook ran on all three
# observed compactions and logged `recovery_injected: yes` every time, while
# Claude Code was replacing its 31,881-character block with a file-path stub.
# `degraded` means the block was too large to land in context at all.
RECOVERED="no"
INJECTED_BYTES=""
#
# THE MARKER IS READ ONLY IF IT IS THIS SESSION'S. ai-dlc-recover.sh records the session it
# wrote for, and this event carries its own session_id. A marker owned by a different session
# is not this compaction's injection -- the recovery hook ran for this session and wrote
# nothing (or did not run), so the truthful report is `no`, never `yes` with another lead's
# byte count. A marker with no owner, or an event with none, is read as before.
_MK_SID=""
[ -f "$MARKER" ] && _MK_SID="$(sed -n 's/^session_id=//p' "$MARKER" 2>/dev/null | head -1)"
_MK_FOREIGN=0
if [ -n "$_MK_SID" ] && [ -n "$_EV_SID" ] && [ "$_MK_SID" != "$_EV_SID" ]; then _MK_FOREIGN=1; fi
if [ -f "$MARKER" ] && [ "$_MK_FOREIGN" -eq 0 ]; then
  INJECTED_BYTES="$(sed -n 's/^injected_bytes=//p' "$MARKER" 2>/dev/null | head -1)"
  DEGRADED="$(sed -n 's/^degraded=//p' "$MARKER" 2>/dev/null | head -1)"
  if [ "${DEGRADED:-no}" = "yes" ]; then
    RECOVERED="degraded-persisted"
  else
    RECOVERED="yes"
  fi
  # READ, NEVER DELETE. This hook used to `rm -f "$MARKER"` here, and it fires on PostCompact,
  # which the harness runs AFTER SessionStart:compact wrote the marker and BEFORE the lead's
  # first tool call. So the file `ai-dlc-recover-gate.sh` arms on was gone one event before
  # that gate could read it, and its `[ -f "$MARKER" ] || exit 0` fast path stood it down
  # silently on every compaction. Measured on the reference consumer: 636 of 637 logged
  # compactions read `recovery_injected: yes` -- this hook READ the marker each time, and
  # reading it was the same call that deleted it -- while the gate's deny text appears in
  # zero of 256 transcripts and all ten post-compaction first calls in one session were
  # non-mandated. Driven by hand with the shipped hooks in sequence: marker PRESENT after
  # recover.sh, ABSENT after this hook, gate silent. The gate is the marker's sole deleter:
  # it removes the file on the call that satisfies the second mandate, and clears it itself
  # when a mandated path has vanished. An unarmable marker (`step_file_resolved=0`) persists
  # for the session by the gate's own design, which is the state this hook's deletion was
  # written for -- and `ai-dlc-recover.sh` rewrites the marker on the next compaction, so it
  # can never carry a stale record across two.
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
  [ -n "$INJECTED_BYTES" ] && printf -- '- injected_bytes: %s\n' "$INJECTED_BYTES"
  printf -- '- summary_bytes: %s\n' "${SUMMARY_BYTES:-0}"
  printf -- '- branch: %s\n' "$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo '(unknown)')"
} >>"$LOG_FILE" 2>/dev/null

case "$RECOVERED" in
  yes)
    printf 'AI/DLC: compaction (%s); recovery directive injected (%s bytes).\n' "$TRIGGER" "$INJECTED_BYTES" ;;
  degraded-persisted)
    printf 'AI/DLC: compaction (%s); recovery directive was %s bytes -- Claude Code stubbed it. Read _bmad-output/pipeline-snapshot.md before continuing.\n' "$TRIGGER" "$INJECTED_BYTES" ;;
  *)
    printf 'AI/DLC: compaction (%s); recovery hook did not fire -- verify state before continuing.\n' "$TRIGGER" ;;
esac

exit 0
