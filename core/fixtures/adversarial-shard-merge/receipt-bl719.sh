#!/usr/bin/env bash
# BL-719 receipt (the key). Usage: bash receipt-bl719.sh [installed|core ...]
# Run from the repo root. Each layout named (default: both) builds four worlds from the subject's
# own siblings: the current readers, and three that each swap in ONE reader from before 0.888.0
# (8df9b8ae6~1): validate-adversarial-convergence.sh, partition-subject.sh, provenance-block.json.
# 0 = `merge-adversarial-shards.sh --pair-sep` prints exactly `@` in the current world and exactly
#     `=` in each old-reader world, in every layout named.
# 1 = a world answered otherwise (a hard-coded `@`, or a key that drops one reader, fails here).
# 9 = the receipt could not run: no subject, no old reader in history, a world identical to the
#     current one, or a subject exit other than 0 or 1.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
OLDREF=8df9b8ae6~1
LAYOUTS="${*:-installed core}"
SRC=core/scripts; SCH=core/schemas/provenance-block.json
[ -f "$SRC/merge-adversarial-shards.sh" ] || { SRC=scripts/ai-dlc; SCH=.claude/schemas/provenance-block.json; }
for f in merge-adversarial-shards.sh validate-adversarial-convergence.sh partition-subject.sh validate-provenance-block.sh; do
  [ -f "$SRC/$f" ] || { echo "REFUSED: no $SRC/$f" >&2; exit 9; }
done
[ -f "$SCH" ] || { echo "REFUSED: no $SCH" >&2; exit 9; }
command -v python3 >/dev/null 2>&1 || { echo "REFUSED: python3 absent; the schema key cannot answer" >&2; exit 9; }
T="$(mktemp -d)" || exit 9
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/old" || exit 9
git show "${OLDREF}:core/scripts/validate-adversarial-convergence.sh" > "$T/old/vac" 2>/dev/null || { echo "REFUSED: no old VAC at $OLDREF" >&2; exit 9; }
git show "${OLDREF}:core/scripts/partition-subject.sh" > "$T/old/ps" 2>/dev/null || { echo "REFUSED: no old partition-subject at $OLDREF" >&2; exit 9; }
git show "${OLDREF}:core/schemas/provenance-block.json" > "$T/old/sch" 2>/dev/null || { echo "REFUSED: no old schema at $OLDREF" >&2; exit 9; }

# world <layout> <name> -> prints the world root; script dir and schema path in WS / WJ.
world() {
  local w="$T/$1-$2"
  case "$1" in
    installed) WS="$w/scripts/ai-dlc"; WJ="$w/.claude/schemas/provenance-block.json" ;;
    core)      WS="$w/core/scripts";   WJ="$w/core/schemas/provenance-block.json" ;;
    *) echo "REFUSED: layout '$1' is not installed|core" >&2; exit 9 ;;
  esac
  mkdir -p "$WS" "$(dirname "$WJ")" || exit 9
  cp "$SRC/merge-adversarial-shards.sh" "$SRC/validate-adversarial-convergence.sh" \
     "$SRC/partition-subject.sh" "$SRC/validate-provenance-block.sh" "$WS/" || exit 9
  cp "$SCH" "$WJ" || exit 9
  WR="$w"
}
# ask <root> <script dir> -> SEP (the exact stdout)
ask() {
  local rc
  SEP="$(AI_DLC_PROJECT_ROOT="$1" bash "$2/merge-adversarial-shards.sh" --pair-sep 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "REFUSED: --pair-sep exited $rc in $1" >&2; exit 9; }
}
fails=0
for L in $LAYOUTS; do
  world "$L" cur; CR="$WR"; CS="$WS"; CJ="$WJ"
  ask "$CR" "$CS"
  [ "$SEP" = "@" ] || { echo "FAIL $L current readers: '$SEP', want '@'"; fails=$((fails + 1)); }
  for o in vac ps sch; do
    world "$L" "$o"
    case "$o" in
      vac) cp "$T/old/vac" "$WS/validate-adversarial-convergence.sh"; a="$CS/validate-adversarial-convergence.sh"; b="$WS/validate-adversarial-convergence.sh" ;;
      ps)  cp "$T/old/ps" "$WS/partition-subject.sh"; a="$CS/partition-subject.sh"; b="$WS/partition-subject.sh" ;;
      sch) cp "$T/old/sch" "$WJ"; a="$CJ"; b="$WJ" ;;
    esac
    cmp -s "$a" "$b" && { echo "REFUSED: the $L old-$o world is identical to the current one" >&2; exit 9; }
    ask "$WR" "$WS"
    [ "$SEP" = "=" ] || { echo "FAIL $L old $o: '$SEP', want '='"; fails=$((fails + 1)); }
  done
done
[ "$fails" -eq 0 ] || exit 1
exit 0
