#!/usr/bin/env bash
# BL-518 receipt probe: does gate-checkpoint.sh's `open` refuse a hand-composed nonce that does not
# match the canonical <gate_type>-<YYYYMMDDTHHMMSSZ> form, before any write, without gating `record`?
#
#   CONTROL  the canonical nonce must OPEN (exit 0), or this probe cannot measure (exit 9)
#   SUBJECT  the hyphenated nonce graph minted at s317 (`implementation-2026-10-11T083048Z`) must
#            exit 2, leave `current` naming the control, and name the canonical form on stderr
#   SCOPE    `deploy-validate-s304-20260822T005500Z` (a gate type outside the schema's closed list)
#            must exit 2; a free-form `record` (`--nonce f1 record 1 PASS`) must still exit 0
#
# exit 0 fixed, 1 live, 9 precondition missing. Measured at 0.781.0: the subject opens with exit 0
# -> probe exit 1. Run from the repo root.
set -uo pipefail
V=core/scripts/gate-checkpoint.sh
[ -f "$V" ] || exit 9
d=$(mktemp -d)
mkdir -p "$d/_bmad-output"
export AI_DLC_PROJECT_ROOT="$d" CLAUDE_PROJECT_DIR="$d"
ctl=implementation-20261011T083048Z
bash "$V" --root "$d" --nonce "$ctl" open >/dev/null 2>&1 || exit 9

err="$(bash "$V" --root "$d" --nonce implementation-2026-10-11T083048Z open 2>&1 >/dev/null)"; rc=$?
[ "$rc" -eq 2 ] || exit 1
[ "$(bash "$V" --root "$d" current 2>/dev/null)" = "$ctl" ] || exit 1
case "$err" in
  *'<gate_type>-YYYYMMDDTHHMMSSZ'*) : ;;
  *) exit 1 ;;
esac

bash "$V" --root "$d" --nonce deploy-validate-s304-20260822T005500Z open >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] || exit 1

bash "$V" --root "$d" --nonce f1 record 1 PASS >/dev/null 2>&1 || exit 1
exit 0
