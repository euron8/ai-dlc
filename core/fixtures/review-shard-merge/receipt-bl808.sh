#!/usr/bin/env bash
# BL-808 receipt (--exclude-captures). Usage: bash receipt-bl808.sh <path to partition-review-diff.sh>
# Drives the partitioner over a mktemp repo shaped like this fixture's XC1-XC3 worlds (lib.sh):
#   (a) DFLT+2 code files and ten captures stay sharded: the map is byte-identical with and without
#       --exclude-captures, and both exit 0 with at least two parts
#   (b) DFLT-1 code files and ten captures: flagless exits 0 (partitions); flagged exits 3 SERIAL
#   (c) the excluded count is the INTERSECTION: a list of nine LF lines, cap10 only as CRLF, one path
#       outside the diff, one path under a scan root and a duplicate prints "10 cited capture(s) not
#       counted" (its length is 13); a list of only the outside and scan-root paths prints 0
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = partition-review-diff.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl808.sh <path to partition-review-diff.sh>" >&2; exit 9; }
PART="$(cd "$(dirname "$1")" && pwd)/partition-review-diff.sh"
SD="$(dirname "$PART")"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SD/artifact-path-config.sh" ] || { echo "REFUSED: artifact-path-config.sh is not beside the partition" >&2; exit 9; }
GRAMMAR=""; _d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/skills/ai-dlc/artifact-path-grammar.md" "$_d/.claude/skills/ai-dlc/artifact-path-grammar.md"; do
    [ -f "$_c" ] && { GRAMMAR="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
[ -n "$GRAMMAR" ] || { echo "REFUSED: no artifact-path-grammar.md above the receipt" >&2; exit 9; }
DFLT="$(sed -n 's/^REVIEW_SHARD_DEFAULT_MIN_FILES=\([0-9][0-9]*\)$/\1/p' "$PART")"
case "$DFLT" in ''|*[!0-9]*) echo "REFUSED: no REVIEW_SHARD_DEFAULT_MIN_FILES assignment in the partition" >&2; exit 9 ;; esac
W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl808.XXXXXX")" || exit 9
trap 'rm -rf "$W"' EXIT
G() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
lines() { local i=0; mkdir -p "$(dirname "$1")"; : > "$1"; while [ "$i" -lt "$2" ]; do i=$((i + 1)); printf '%s line %d\n' "$3" "$i" >> "$1"; done; }
R="$W/repo"; mkdir -p "$R/core/skills/ai-dlc" && G init -q "$R" || exit 9
cp "$GRAMMAR" "$R/core/skills/ai-dlc/artifact-path-grammar.md"; printf 'seed\n' > "$R/README"
G -C "$R" add -A && G -C "$R" commit -q -m base || exit 9
i=0; while [ "$i" -lt "$((DFLT + 2))" ]; do i=$((i + 1)); lines "$R/x$((i % 4))/c$i.py" "$((i + 4))" "x-$i"; done
i=0; while [ "$i" -lt 10 ]; do i=$((i + 1)); lines "$R/evidence/s1/cap$i.txt" 3 "cap-$i"; done
G -C "$R" add -A && G -C "$R" commit -q -m x1 \
  && G -C "$R" rm -q x1/c1.py x2/c2.py x3/c3.py && G -C "$R" commit -q -m x2 || exit 9
lines "$R/docs/reviews/s1/r.txt" 3 r
G -C "$R" add -A && G -C "$R" commit -q -m x3 || exit 9
BASE="$(G -C "$R" rev-parse HEAD~3)"; X1="$(G -C "$R" rev-parse HEAD~2)"
X2="$(G -C "$R" rev-parse HEAD~1)"; X3="$(G -C "$R" rev-parse HEAD)"
ALL="$W/all"; SEED="$W/seed"; NONE="$W/none"; : > "$ALL"
i=0; while [ "$i" -lt 10 ]; do i=$((i + 1)); printf 'evidence/s1/cap%d.txt\n' "$i" >> "$ALL"; done
{ sed -n '1,9p' "$ALL"; printf 'evidence/s1/cap10.txt\r\n'; printf 'nowhere/else/out.txt\ndocs/reviews/s1/r.txt\nevidence/s1/cap1.txt\n'; } > "$SEED"
printf 'nowhere/else/out.txt\ndocs/reviews/s1/r.txt\n' > "$NONE"
run() { # <out> <args...> -> RC
  local o="$1"; shift
  bash "$PART" --map "$R" "$@" > "$o" 2> "$o.err" < /dev/null; RC=$?
}
fails=0
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
# (a)
run "$W/a0" "$BASE" "$X1"; a0=$RC
run "$W/a1" "$BASE" "$X1" --exclude-captures "$ALL"; a1=$RC
np="$(grep -cE '^[0-9]+	' "$W/a1")" || np=0
{ [ "$a0" -eq 0 ] && [ "$a1" -eq 0 ] && [ "$np" -ge 2 ] && cmp -s "$W/a0" "$W/a1"; } || bad "a: rc=$a0/$a1 parts=$np identical=$(cmp -s "$W/a0" "$W/a1" && echo y || echo n)"
# (b)
run "$W/b0" "$BASE" "$X2"; b0=$RC
run "$W/b1" "$BASE" "$X2" --exclude-captures "$ALL"; b1=$RC
{ [ "$b0" -eq 0 ] && [ "$b1" -eq 3 ] && grep -q '^SERIAL: ' "$W/b1"; } || bad "b: flagless rc=$b0 flagged rc=$b1"
# (c)
run "$W/c1" "$BASE" "$X3" --min-files 100 --exclude-captures "$SEED"; c1=$RC
run "$W/c2" "$BASE" "$X3" --min-files 100 --exclude-captures "$NONE"; c2=$RC
{ [ "$c1" -eq 3 ] && grep -qF ' 10 cited capture(s) not counted' "$W/c1"; } || bad "c-seed: rc=$c1 [$(head -1 "$W/c1")]"
{ [ "$c2" -eq 3 ] && grep -qF ' 0 cited capture(s) not counted' "$W/c2"; } || bad "c-none: rc=$c2 [$(head -1 "$W/c2")]"
[ "$fails" -eq 0 ] || exit 1
exit 0
