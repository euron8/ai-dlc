#!/usr/bin/env bash
# BL-804 receipt. Usage: bash receipt-bl804.sh [<wait-for-deliverable.sh to drive> [<derivations value>]]
# Run from the repo root. Drives --mark on a scratch copy of the core scripts (or the script named by $1,
# which must sit beside its siblings in a copy) over two remediator parts at
# planning-artifacts/s9/shards/stories-repair-p1/, each a repaired entry stating `derivations: <value>`
# (default `not replayed`; $2 names another spelling, e.g. a backticked one):
#   01.md, two fences that reproduce -> must be marked with the line rewritten to `replayed 2`;
#   02.md, one stale fence -> must be refused 64 with the file byte-identical.
# 0 = both hold.
# 1 = 01.md was not marked, or its line does not read `replayed 2`.
# 3 = 02.md was marked or changed: a stale record was sealed (the validator's verdict was not read).
# 9 = the receipt could not run.
set -uo pipefail
[ -f core/scripts/wait-for-deliverable.sh ] || { echo "REFUSED: run from the distribution root" >&2; exit 9; }
T="$(mktemp -d)" || exit 9
mkdir -p "$T/s" || exit 9
cp core/scripts/*.sh "$T/s/" || exit 9
W="${1:-$T/s/wait-for-deliverable.sh}"
V="${2:-not replayed}"
[ -f "$W" ] || exit 9
PA="$T/w/_bmad-output/planning-artifacts"; SD="$PA/s9/shards/stories-repair-p1"
mkdir -p "$SD" || exit 9
printf 'tok\ntok\nzed\n' > "$PA/s9/data.txt" || exit 9
part() { # <file> <recorded tok count>
  printf -- '- artifact: _bmad-output/planning-artifacts/s9/data.txt\n- artifact_sha_before: x\n- artifact_sha_after: y\n- advisor: called\n- derivations: %s\n\n### F-1 — MAJOR\n- disposition: repaired\n- edit: _bmad-output/planning-artifacts/s9/data.txt:1\n\n```derived\n$ grep -c tok _bmad-output/planning-artifacts/s9/data.txt\n%s\n$ grep -c zed _bmad-output/planning-artifacts/s9/data.txt\n1\n```\n' "$V" "$2" > "$1"
}
part "$SD/01.md" 2 || exit 9
part "$SD/02.md" 3 || exit 9
cp "$SD/02.md" "$T/02.before" || exit 9
bash "$W" --mark "$SD/01.md" stories remediator 01 findings=1 > /dev/null 2>&1 || exit 1
n="$(grep -c '^- derivations: replayed 2$' "$SD/01.md")" || n=0
[ "$n" = 1 ] || exit 1
bash "$W" --mark "$SD/02.md" stories remediator 02 findings=1 > /dev/null 2>&1; rc=$?
[ "$rc" = 64 ] && cmp -s "$SD/02.md" "$T/02.before" || exit 3
exit 0
