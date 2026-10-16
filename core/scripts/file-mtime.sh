#!/usr/bin/env bash
# file-mtime.sh -- state each path's modification time as an epoch and an ISO UTC stamp.
#
# Usage: file-mtime.sh <path> [<path> ...]
# Output, one line per path:  <path>TAB<epoch>TAB<YYYY-MM-DDTHH:MM:SSZ>
#                             <path>TAB MISSING   when there is no such file
# Exit:  0 = every path stated, 1 = at least one path MISSING (all paths still reported),
#        2 = no arguments.
#
# WHY THIS IS A SCRIPT AND NOT THE ONE-LINER `date -u -r <path>`. BSD `date -r` takes
# EITHER a file OR an epoch, and an ALL-DIGIT argument is read as the epoch: a file named
# `1792126782` whose mtime is in 2020 printed 2026-10-16T04:59:42Z, the time its NAME
# spells. A record file named after a timestamp is exactly the kind a dispatch comparison
# is run against. This script takes the epoch from `stat` and hands `date` only that
# number, so a numeric basename can never be mistaken for a time.
#
# STAT FLAVOUR IS CHOSEN BY THE SHAPE OF THE ANSWER, never by the exit status. `stat -f`
# is `--file-system` on GNU: it exits 0 and prints filesystem text for an unknown format,
# so a probe keyed on the exit code detects BSD on Linux. Only a bare run of digits is
# accepted from either spelling. The same rule is `fkey` in
# core/hooks/ai-dlc-gate-remediation-guard.sh.
#
# ISO FORMATTING tries GNU `date -u -d @E` first and BSD `date -u -r E` second, the order
# wait-for-deliverable.sh and validate-scope-confirmation.sh use: BSD fails loudly on `-d`,
# whereas GNU reads `-r E` as a file NAME.
set -uo pipefail

[ $# -ge 1 ] || { echo "usage: file-mtime.sh <path> [<path> ...]" >&2; exit 2; }

mtime_epoch() { # <path> -> epoch on stdout, nothing when unreadable
  _e="$(stat -f %m "$1" 2>/dev/null)"
  case "${_e:-}" in ''|*[!0-9]*) : ;; *) printf '%s' "$_e"; return 0 ;; esac
  _e="$(stat -c %Y "$1" 2>/dev/null)"
  case "${_e:-}" in ''|*[!0-9]*) : ;; *) printf '%s' "$_e"; return 0 ;; esac
  return 1
}

iso_utc() { # <epoch> -> YYYY-MM-DDTHH:MM:SSZ
  date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null && return 0
  return 1
}

rc=0
for p in "$@"; do
  if [ ! -e "$p" ]; then
    printf '%s\tMISSING\n' "$p"; rc=1; continue
  fi
  if ! ep="$(mtime_epoch "$p")" || ! iso="$(iso_utc "$ep")"; then
    printf '%s\tMISSING\n' "$p"; rc=1; continue
  fi
  printf '%s\t%s\t%s\n' "$p" "$ep" "$iso"
done
exit "$rc"
