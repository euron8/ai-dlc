#!/usr/bin/env bash
# BL-763 receipt (every owner-duplicate refusal in one run). Usage: bash receipt-bl763.sh <path to merge-review-shards.sh>
# The script's own directory is driven, so it must hold the merge's siblings. Worlds are this fixture's
# lib.sh K=3 world (groups 1:(1,2) 2:(1,3) 3:(2,3); the default cross shards each cite their own group's
# set), built in its own mktemp WORK. Each case adds findings with xfinding and runs the full merge.
#   two duplicates in two seats: cross-2 cites 1, 2 (owned by cross-1, which carries it) and cross-3 cites
#     1, 3 (owned by cross-2, which carries it)  -> exit 2, exactly 2 REFUSED lines, tails cross-2 then
#     cross-3, nothing written
#   one duplicate (cross-2 cites 1, 2)          -> exit 2, exactly 1 REFUSED line, tail cross-2, nothing written
#   near-miss: cross-1 cites 1, 2 a second time (its own set) -> merges, exit 0
#   --check-shard over cross-2's duplicate, its owner sealed -> exit 2, one REFUSED line, no SHARD-OK
#   the duplicate in cross-2, then a per-shard refusal in cross-3 -> both, the duplicate first
#   a per-shard refusal in cross-1, the duplicate after it in cross-3 -> cross-1's alone
#   ONE shard printing both: cross-2's duplicate, then cross-2's own verdict-backing refusal (an APPROVED
#     shard carrying a Critical finding) -> 2 REFUSED lines, both [owner: cross-2], the duplicate first
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl763.sh <path to merge-review-shards.sh>" >&2; exit 9; }
HERE="$(cd "$(dirname "$0")" && pwd)"
SD="$(cd "$(dirname "$1")" && pwd)"
for _s in partition-review-diff.sh partition-document.sh artifact-path-config.sh content-seal.sh wait-for-deliverable.sh; do
  [ -f "$SD/$_s" ] || { echo "REFUSED: $_s is not beside $1; the merge resolves it there" >&2; exit 9; }
done
[ -f "$HERE/lib.sh" ] || { echo "REFUSED: no $HERE/lib.sh" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl763.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT

(
  NAME=receipt-bl763
  . "$HERE/lib.sh" > /dev/null 2>&1 || exit 9
  tails() { grep '^REFUSED:' "$MO" | sed -n 's/.*\[owner: \([^]]*\)\]$/\1/p' | tr '\n' ' '; }
  first() { local l; l="$(grep -m1 '^REFUSED:' "$MO")"; grep -q 'identical set' <<<"$l" && echo dup || echo other; }
  wr() { [ -e "$o" ] && echo y || echo n; }
  zsha() { sed 's/^reviewed-sha: .*/reviewed-sha: 0000000000000000000000000000000000000000/' "$1" > "$1.x" && mv "$1.x" "$1"; }
  crit() {
    awk '/^### Critical/ && !d { print; printf "\n#### F-crit a critical interaction\nparts: 1, 3\n\nBody.\n"; d = 1; next } { print }' \
      "$1" > "$1.x" && mv "$1.x" "$1" && grep -q '^#### F-crit ' "$1"
  }
  d="$(world4 "$SD" APPROVED APPROVED APPROVED APPROVED)" || exit 9
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || exit 9
  o="$(out_of "$d")"
  xfinding "$d/cross-2.md" F-dupA "1, 2" && xfinding "$d/cross-3.md" F-dupB "1, 3" || exit 9
  run_merge "$SD" "$d"; printf 'two rc=%s n=%s tails=%s written=%s\n' "$RC" "$(nref "$MO")" "$(tails)" "$(wr)"
  rm -f "$o"; cs_reset "$d" "$c"
  xfinding "$d/cross-2.md" F-dupA "1, 2" || exit 9
  run_merge "$SD" "$d"; printf 'one rc=%s n=%s tails=%s written=%s\n' "$RC" "$(nref "$MO")" "$(tails)" "$(wr)"
  rm -f "$o"; cs_reset "$d" "$c"
  xfinding "$d/cross-1.md" F-ownB "1, 2" || exit 9
  run_merge "$SD" "$d"; printf 'near rc=%s merged=%s\n' "$RC" "$(has "$MO" "MERGED:" && echo y || echo n)"
  rm -f "$o"; cs_reset "$d" "$c"
  xfinding "$d/cross-2.md" F-dupA "1, 2" || exit 9
  lmark "$d/cross-1.md" - cross-1 key=cross-1
  run_check "$SD" "$d" code-review "$d/cross-2.md"
  printf 'check rc=%s n=%s ok=%s\n' "$CRC" "$(nref "$CO")" "$(has "$CO" "SHARD-OK" && echo y || echo n)"
  cs_reset "$d" "$c"
  xfinding "$d/cross-2.md" F-dupA "1, 2" || exit 9
  zsha "$d/cross-3.md" || exit 9
  run_merge "$SD" "$d"; printf 'preca rc=%s n=%s tails=%s first=%s written=%s\n' "$RC" "$(nref "$MO")" "$(tails)" "$(first)" "$(wr)"
  rm -f "$o"; cs_reset "$d" "$c"
  zsha "$d/cross-1.md" || exit 9
  xfinding "$d/cross-3.md" F-dupB "1, 3" || exit 9
  run_merge "$SD" "$d"; printf 'precb rc=%s n=%s tails=%s written=%s\n' "$RC" "$(nref "$MO")" "$(tails)" "$(wr)"
  rm -f "$o"; cs_reset "$d" "$c"
  xfinding "$d/cross-2.md" F-dupA "1, 2" && crit "$d/cross-2.md" || exit 9
  run_merge "$SD" "$d"; printf 'same rc=%s n=%s tails=%s first=%s written=%s\n' "$RC" "$(nref "$MO")" "$(tails)" "$(first)" "$(wr)"
  exit 0
) > "$R/rows" 2> "$R/err"
rc=$?
[ "$rc" -eq 0 ] || { echo "REFUSED: the receipt's worlds did not build (rc=$rc): $(head -1 "$R/err")" >&2; exit 9; }
[ "$(grep -c . "$R/rows")" = 7 ] || { echo "REFUSED: not every case answered" >&2; exit 9; }
cat "$R/rows" >&2
fails=0
grep -qxF 'two rc=2 n=2 tails=cross-2 cross-3  written=n' "$R/rows" || { echo "FAIL two"; fails=$((fails + 1)); }
grep -qxF 'one rc=2 n=1 tails=cross-2  written=n' "$R/rows" || { echo "FAIL one"; fails=$((fails + 1)); }
grep -qxF 'near rc=0 merged=y' "$R/rows" || { echo "FAIL near"; fails=$((fails + 1)); }
grep -qxF 'check rc=2 n=1 ok=n' "$R/rows" || { echo "FAIL check"; fails=$((fails + 1)); }
grep -qxF 'preca rc=2 n=2 tails=cross-2 cross-3  first=dup written=n' "$R/rows" || { echo "FAIL preca"; fails=$((fails + 1)); }
grep -qxF 'precb rc=2 n=1 tails=cross-1  written=n' "$R/rows" || { echo "FAIL precb"; fails=$((fails + 1)); }
grep -qxF 'same rc=2 n=2 tails=cross-2 cross-2  first=dup written=n' "$R/rows" || { echo "FAIL same"; fails=$((fails + 1)); }
[ "$fails" -eq 0 ] || exit 1
exit 0
