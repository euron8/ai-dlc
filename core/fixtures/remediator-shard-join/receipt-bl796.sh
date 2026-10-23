#!/usr/bin/env bash
# BL-796 receipt. Usage: bash receipt-bl796.sh [<wait-for-deliverable.sh to drive>]   Run from the repo root.
# Drives --mark on a scratch copy of the core scripts (or the script named by $1, which must sit beside its siblings
# in a copy) over a part at planning-artifacts/s9/shards/coe-repair-p1/7.md called with the SHIFTED words
# `coe 7 remediator 7`, and over requirements-party-repair/05.md called with the correct words.
# 0 = the marker lines read `coe remediator 7` and `requirements-party remediator 05`.
# 1 = the caller's words were written, or the step kept its -p<M>.
# 9 = the receipt could not run.
set -uo pipefail
[ -f core/scripts/wait-for-deliverable.sh ] || { echo "REFUSED: run from the distribution root" >&2; exit 9; }
T="$(mktemp -d)" || exit 9
mkdir -p "$T/s" || exit 9
cp core/scripts/*.sh "$T/s/" || exit 9
W="${1:-$T/s/wait-for-deliverable.sh}"
[ -f "$W" ] || exit 9
SD="$T/w/_bmad-output/planning-artifacts/s9/shards"
mkdir -p "$SD/coe-repair-p1" "$SD/requirements-party-repair" || exit 9
printf '# part\n\nbody\n' > "$SD/coe-repair-p1/7.md" || exit 9
printf '# part\n\nbody\n' > "$SD/requirements-party-repair/05.md" || exit 9
bash "$W" --mark "$SD/coe-repair-p1/7.md" coe 7 remediator 7 findings=1 > /dev/null 2>&1 || exit 9
bash "$W" --mark "$SD/requirements-party-repair/05.md" requirements-party remediator 05 findings=0 > /dev/null 2>&1 || exit 9
a="$(tail -n 1 "$SD/coe-repair-p1/7.md")"; b="$(tail -n 1 "$SD/requirements-party-repair/05.md")"
case "$a" in "seat-complete: coe remediator 7 sha="*" findings=1") ;; *) exit 1 ;; esac
case "$b" in "seat-complete: requirements-party remediator 05 sha="*" findings=0") ;; *) exit 1 ;; esac
exit 0
