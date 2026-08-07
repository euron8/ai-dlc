#!/usr/bin/env bash
# notify-hook-channel/seed.sh — a work tree with a shimmed PATH, so the hook's REAL platform
# branch can be driven on any machine.
#
# THE SEAM IS $PATH, DELIBERATELY. The hook resolves its channel with `uname -s` and
# `command -v`; shimming those three binaries drives the shipping code rather than a test-only
# env var. A branch that only the machine running the suite can reach is a branch the suite
# cannot prove — and this repo's recurring defect is a check that cannot fire.
#
# The shims RECORD rather than notify: a fixture that raised a real desktop notification on
# every pre-push would be turned off within a week, and `osascript` on a Linux runner does not
# exist at all.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS. install.sh splits what shares a parent here: core/hooks/<x> becomes
# .claude/hooks/<x>. Never walk up from one core file to find another (I33).
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-notify.sh" ]; then
  HOOK="$ROOT/core/hooks/ai-dlc-notify.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/hooks/ai-dlc-notify.sh" ]; then
  HOOK="$ROOT/.claude/hooks/ai-dlc-notify.sh"
else
  echo "FIXTURE ERROR: ai-dlc-notify.sh not found in either layout" >&2; exit 2
fi

# install.sh is DISTRIBUTION-ONLY. Its absence is the consumer layout, not a failure; the
# assertion that reads it declares itself SKIPPED there rather than passing quietly.
INSTALL_SH=""
[ -n "$ROOT" ] && [ -f "$ROOT/scripts/install.sh" ] && INSTALL_SH="$ROOT/scripts/install.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/notify-channel.XXXXXX")" || exit 2
mkdir -p "$WORK/bin" "$WORK/rec"

# --- the uname shim -----------------------------------------------------------------------
# Reads the platform to report from a file, so an arm switches platform by writing one word.
printf '%s\n' "Darwin" > "$WORK/platform"
cat > "$WORK/bin/uname" <<SHIM
#!/usr/bin/env bash
if [ "\${1:-}" = "-s" ]; then cat "$WORK/platform"; else cat "$WORK/platform"; fi
SHIM

# --- the osascript shim -------------------------------------------------------------------
# Records argv one-per-line AND the script text it received on stdin. Both are needed: the
# injection control asserts the payload is in the FIRST and absent from the SECOND.
cat > "$WORK/bin/osascript" <<SHIM
#!/usr/bin/env bash
: > "$WORK/rec/osascript.argv"
for a in "\$@"; do printf '%s\n' "\$a" >> "$WORK/rec/osascript.argv"; done
cat > "$WORK/rec/osascript.stdin"
exit 0
SHIM

# --- the notify-send shim -----------------------------------------------------------------
cat > "$WORK/bin/notify-send" <<SHIM
#!/usr/bin/env bash
: > "$WORK/rec/notify-send.argv"
for a in "\$@"; do printf '%s\n' "\$a" >> "$WORK/rec/notify-send.argv"; done
exit 0
SHIM

chmod +x "$WORK/bin/uname" "$WORK/bin/osascript" "$WORK/bin/notify-send"

mkdir -p "$WORK/project"

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
INSTALL_SH="$INSTALL_SH"
WORK="$WORK"
SHIMBIN="$WORK/bin"
PLATFORM_FILE="$WORK/platform"
REC="$WORK/rec"
PROJECT="$WORK/project"
ENV

printf '%s\n' "$WORK"
