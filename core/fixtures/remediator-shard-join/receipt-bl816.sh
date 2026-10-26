#!/usr/bin/env bash
# BL-816 receipt. Usage: bash receipt-bl816.sh [<wait-for-deliverable.sh to drive> [<derivations label>]]
# Run from the repo root. Drives --mark-repair on a scratch copy of the core scripts (or the script named by
# $1, which must sit beside its siblings in a copy) over two joined records under planning-artifacts/s9/,
# each a shard segment (lines 3-17) above a serial block claiming `<label> replayed 2` (default label
# `- derivations:`; $2 names another spelling, e.g. `- **derivations:**`):
#   shard.md, the SHARD segment's fence stale, the serial block's fence clean -> must be marked;
#   first.md, the serial block's first fence (line 20, under its triple on 18) stale -> must be refused 64
#             with the file byte-identical.
# 0 = both hold.
# 1 = shard.md was refused: a FAIL outside the block being sealed was charged to it.
# 3 = first.md was marked or changed: a stale fence inside the claimed block was sealed.
# 4 = with the validator crashed (exit 1, no `FAIL: <n> stale or unrunnable` summary) the stale block was
#     marked, changed, or refused as anything but no verdict. NOTE: $1 given, its sibling validator is
#     swapped for the crashed copy for that one call and restored, so name a script inside a scratch copy.
# 9 = the receipt could not run.
set -uo pipefail
[ -f core/scripts/wait-for-deliverable.sh ] || { echo "REFUSED: run from the distribution root" >&2; exit 9; }
T="$(mktemp -d)" || exit 9
mkdir -p "$T/s" || exit 9
cp core/scripts/*.sh "$T/s/" || exit 9
W="${1:-$T/s/wait-for-deliverable.sh}"
L="${2:-- derivations:}"
[ -f "$W" ] || exit 9
PA="$T/w/_bmad-output/planning-artifacts"; D=_bmad-output/planning-artifacts/s9/data.txt
mkdir -p "$PA/s9" || exit 9
printf 'tok\ntok\nzed\n' > "$PA/s9/data.txt" || exit 9
rec() { # <file> <shard fence's recorded count> <serial fence's recorded count>
  { printf '# Repair record\n\n<!-- shard: 01 -->\n- artifact: %s\n- artifact_sha_before: x\n- artifact_sha_after: y\n- advisor: called\n- derivations: replayed 1\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: %s:1\n\n```derived\n$ grep -c tok %s\n%s\n```\n' "$D" "$D" "$D" "$2"
    printf -- '- artifact: %s\n```derived\n$ grep -c zed %s\n%s\n```\n- artifact_sha_before: y\n- artifact_sha_after: z\n- advisor: called\n%s replayed 2\n\n### S-1 — MAJOR\n- disposition: repaired\n- edit: n/a (no edit)\n' "$D" "$D" "$3" "$L"; } > "$1"
}
rec "$PA/s9/shard.md" 5 1 || exit 9
rec "$PA/s9/first.md" 2 4 || exit 9
cp "$PA/s9/first.md" "$T/first.before" || exit 9
bash "$W" --mark-repair "$PA/s9/shard.md" 1 > /dev/null 2>&1 || exit 1
bash "$W" --mark-repair "$PA/s9/first.md" 1 > /dev/null 2>&1; rc=$?
[ "$rc" = 64 ] && cmp -s "$PA/s9/first.md" "$T/first.before" || exit 3
# crash.md: first.md's world, the validator beside the driven script dying under `set -u` after its
# `set -uo pipefail` (exit 1, no FAIL line) -> must be refused 64, file byte-identical, as no verdict.
VD="$(dirname "$W")/validate-artifact-derivations.sh"; [ -f "$VD" ] || exit 9
awk '{ print } /^set -uo pipefail$/ && !d { print "echo \"$AI_DLC_NO_SUCH_VAR_X\" > /dev/null"; d = 1 }' "$VD" > "$T/v.crash" || exit 9
cmp -s "$VD" "$T/v.crash" && exit 9
cp "$VD" "$T/v.orig" && cp "$T/v.crash" "$VD" || exit 9
rec "$PA/s9/crash.md" 2 4 || exit 9
cp "$PA/s9/crash.md" "$T/crash.before" || exit 9
bash "$W" --mark-repair "$PA/s9/crash.md" 1 > "$T/crash.out" 2>&1; rc=$?
cp "$T/v.orig" "$VD" || exit 9
[ "$rc" = 64 ] && cmp -s "$PA/s9/crash.md" "$T/crash.before" && grep -q 'gave no verdict (exit 1)' "$T/crash.out" || exit 4
exit 0
