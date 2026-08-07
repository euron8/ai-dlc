#!/usr/bin/env bash
#
# AI/DLC Input-Needed Notification Hook
#
# PURPOSE
# Raises a desktop notification when the session needs the operator. The operator cannot see
# a running session; from outside, "still working" and "stopped, waiting on you" look
# identical, so silence is a stall found only by polling. Measured across this repo's own
# runs, EVERY consumer-session stall ended with the operator asking rather than the session
# reporting — including one sitting on a blocking question and one that had already FINISHED.
#
# WHY A HOOK RATHER THAN THE ASSISTANT CALLING PushNotification. The harness runs this; it
# cannot be forgotten, and it does not depend on a lead remembering a rule that a compaction
# may have dropped. PushNotification is the assistant's own call and it SELF-SUPPRESSES while
# the terminal is active ("this terminal is active, so your output here already reaches the
# user"), which means the ping sent the instant the session gets blocked is exactly the one
# that never arrives. This hook covers the desktop; PushNotification still covers mobile.
#
# WHY THE `Notification` EVENT AND NOT `Stop`. `Notification` is raised for permission
# prompts and for idle-waiting — the two states that ARE "waiting on you". `Stop` fires at the
# end of every single response, which would train the operator to ignore the alert, and an
# alert nobody reads is worse than none.
#
# THE MESSAGE IS PASSED AS AN ARGUMENT, NEVER INTERPOLATED INTO THE SCRIPT TEXT. A payload
# containing a double quote, a backslash or `$(...)` would otherwise break the AppleScript or,
# worse, execute as part of it. `osascript - "$msg" "$proj"` puts the payload in `argv` where
# AppleScript can only read it as data; the script body is a quoted heredoc, so the shell
# never expands anything inside it either. The fixture `notify-hook-channel` drives a hostile
# payload through and asserts BOTH halves: the argument arrives byte-exact, and the script
# text does not contain it.
#
# PLATFORMS — DECIDED EXPLICITLY, NOT LEFT TO CHANCE.
#   Darwin  -> `osascript`     (Notification Center)
#   Linux   -> `notify-send`   (libnotify; present on any desktop with a notification daemon)
#   other, or the tool absent -> NO channel. The hook exits 0 having notified nothing.
#
# A hook that silently does nothing on an unsupported platform is the inert-mechanism class
# this repo keeps shipping, so the no-channel case is REPORTABLE rather than silent:
# `--probe` prints the resolved channel and the platform it resolved on, and
# `scripts/install.sh` runs it and prints the answer at install time. That is where an
# operator on an unsupported platform finds out — once, in the install output, rather than by
# noticing over weeks that no notification has ever arrived. At notification time the
# no-channel branch also writes one line to stderr.
#
# NEVER BLOCKS. This hook observes; it has no verdict. Every path exits 0. A notifier that can
# fail a harness event would make the session's ability to ask a question depend on its
# ability to talk to a notification daemon.
#
# USAGE
#   ai-dlc-notify.sh            reads the hook payload on stdin, notifies, exits 0
#   ai-dlc-notify.sh --probe    prints `channel=<name>` and `platform=<uname -s>`, exits 0
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-notify.sh
# 2. chmod +x .claude/hooks/ai-dlc-notify.sh
# 3. Add to .claude/settings.json hooks:
#      "Notification": [
#        {
#          "hooks": [{
#            "type": "command",
#            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-notify.sh"
#          }]
#        }
#      ]
# 4. Restart Claude Code
# 5. Verify with /hooks

set -u

# The platform branch, in one place, so `--probe` and the notification path can never
# disagree about which channel this machine has. Resolving it twice is how a probe that
# reports `osascript` ends up beside a run that took the `none` branch.
resolve_channel() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Darwin) command -v osascript   >/dev/null 2>&1 && { printf 'osascript\n';   return 0; } ;;
    Linux)  command -v notify-send >/dev/null 2>&1 && { printf 'notify-send\n'; return 0; } ;;
  esac
  printf 'none\n'
}

if [ "${1:-}" = "--probe" ]; then
  printf 'channel=%s\n' "$(resolve_channel)"
  printf 'platform=%s\n' "$(uname -s 2>/dev/null || echo unknown)"
  exit 0
fi

PAYLOAD="$(cat)"

# jq is required to read the payload. Absent it, the hook still notifies — with the default
# text. A notification saying only "input needed" is the whole point of the hook; the message
# body is detail. This is the one place where degrading is better than exiting.
MSG=""
CWD=""
if command -v jq >/dev/null 2>&1; then
  MSG="$(printf '%s' "$PAYLOAD" | jq -r '.message // empty' 2>/dev/null)"
  CWD="$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null)"
fi
[ -n "$MSG" ] || MSG="Claude Code needs your input"

# Project name as the subtitle, so several concurrent sessions are distinguishable. An
# operator running three of these at once gets three alerts that look the same without it.
[ -n "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJ="$(basename "$CWD")"

case "$(resolve_channel)" in
  osascript)
    osascript - "$MSG" "$PROJ" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  display notification (item 1 of argv) with title "Claude Code" subtitle (item 2 of argv) sound name "Glass"
end run
APPLESCRIPT
    ;;
  notify-send)
    notify-send -- "Claude Code — $PROJ" "$MSG" >/dev/null 2>&1
    ;;
  *)
    printf 'ai-dlc-notify: no desktop notification channel on %s; nothing was raised. Run `.claude/hooks/ai-dlc-notify.sh --probe` for the resolved channel.\n' \
      "$(uname -s 2>/dev/null || echo unknown)" >&2
    ;;
esac

exit 0
