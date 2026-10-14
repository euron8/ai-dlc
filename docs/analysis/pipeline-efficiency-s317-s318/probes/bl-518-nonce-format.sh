#!/usr/bin/env bash
# BL-518 receipt probe: does gate-checkpoint.sh refuse a hand-composed nonce that does not match
# the canonical <gate>-<YYYYMMDDTHHMMSSZ> form?
#
#   CONTROL  the canonical nonce must OPEN (exit 0), or this probe cannot measure (exit 9)
#   SUBJECT  the hyphenated nonce graph minted at s317 (`implementation-2026-10-10T083048Z`)
#            -> exit 0 if gate-checkpoint refuses it with its refusal code 2 (fixed), 1 if it opens (live)
#
# Measured at 0.781.0: both open, exit 0 each -> probe exit 1. Run from the repo root.
set -u
V=core/scripts/gate-checkpoint.sh
[ -f "$V" ] || exit 9
d=$(mktemp -d)
mkdir -p "$d/_bmad-output"
export AI_DLC_PROJECT_ROOT="$d" CLAUDE_PROJECT_DIR="$d"
bash "$V" --nonce implementation-20261010T083048Z open >/dev/null 2>&1 || exit 9
bash "$V" --nonce implementation-2026-10-10T083048Z open >/dev/null 2>&1
[ $? -eq 2 ] && exit 0
exit 1
