#!/bin/bash
# collect-counted-stores.sh -- list, and with --apply remove, the counted verdict stores no push can read.
#
#   bash scripts/collect-counted-stores.sh [--apply] [--base DIR]
#
# Off-gate: nothing in a push runs it. Run from the root of a worktree of this repo. A push reads exactly two
# counted stores under the base (default ~/.cache/ai-dlc/verdicts): the live one, counted-<vk> for the judge's
# current format, and the legacy one fxcount_arm names on its `fxcount_legacy=` line. Both are DERIVED, never listed
# here: the live name is the judge's --store-key, the one fxcount_arm reads (refused if fxcount_arm, extracted from
# .githooks/pre-push, no longer names it), and the legacy vk is the first field of that line. Every other directory of the base named exactly
# `counted-` + 12 lowercase hex is dead. A dry run (the default) prints each dead store and its file count. --apply
# removes the files of each dead store BY EXACT LISTING (one `find -type f` per store, each path passed to rm), then
# removes the emptied directories with rmdir, which refuses a directory that still holds anything.
#
# Exit: 0 done (or nothing to collect), 2 refused (no hook, arming failed, a kept store not derivable).
set -u
apply=0; base="$HOME/.cache/ai-dlc/verdicts"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1; shift ;;
    --base) [ -n "${2:-}" ] || { echo "usage: $0 [--apply] [--base DIR]" >&2; exit 2; }; base="$2"; shift 2 ;;
    *) echo "usage: $0 [--apply] [--base DIR]" >&2; exit 2 ;;
  esac
done
HOOK="$PWD/.githooks/pre-push"
[ -f "$HOOK" ] && [ -f "$PWD/scripts/validate-fixture-invocations.sh" ] \
  || { echo "collect-counted-stores: run from the root of a worktree (no .githooks/pre-push or the judge here)" >&2; exit 2; }
[ -d "$base" ] || { echo "collect-counted-stores: no store base $base: nothing to collect"; exit 0; }
work="$(mktemp -d "${TMPDIR:-/tmp}/collectcs.XXXXXX")" || exit 2
trap 'rm -rf "$work"' EXIT
awk '/^fxcount_arm\(\) \{/ { on = 1 } on { print } on && /^}/ { exit }' "$HOOK" > "$work/arm.sh"
grep -q '^fxcount_arm() {' "$work/arm.sh" || { echo "collect-counted-stores: could not extract fxcount_arm from $HOOK" >&2; exit 2; }
grep -q -e '--store-key' "$work/arm.sh" || { echo "collect-counted-stores: fxcount_arm does not name its store by the judge's --store-key" >&2; exit 2; }
live="$(bash "$PWD/scripts/validate-fixture-invocations.sh" --store-key)" || { echo "collect-counted-stores: the judge printed no store key" >&2; exit 2; }
legacy="$(sed -n 's/^  local fxcount_legacy="\([0-9a-f]\{12\}\) .*/\1/p' "$work/arm.sh")"
lr='^counted-[0-9a-f]{12}$'
grep -Eq "$lr" <<< "$live" || { echo "collect-counted-stores: arming set no counted store ($live)" >&2; exit 2; }
[ "$(printf '%s\n' "$legacy" | grep -c .)" = 1 ] || { echo "collect-counted-stores: no single fxcount_legacy line in fxcount_arm" >&2; exit 2; }
legacy="counted-$legacy"
printf 'keep: %s (live)\nkeep: %s (legacy)\n' "$live" "$legacy"
n=0; nf=0
for d in "$base"/counted-*; do
  [ -d "$d" ] || continue
  s="${d##*/}"
  grep -Eq "$lr" <<< "$s" || continue
  [ "$s" = "$live" ] || [ "$s" = "$legacy" ] && continue
  find "$d" -type f > "$work/files"
  c="$(awk 'END { print NR }' "$work/files")"
  n=$((n + 1)); nf=$((nf + c))
  if [ "$apply" = 0 ]; then printf 'dead: %s (%s file(s))\n' "$s" "$c"; continue; fi
  while IFS= read -r f; do rm -f -- "$f"; done < "$work/files"
  find "$d" -depth -type d -exec rmdir {} \; 2>/dev/null
  if [ -e "$d" ]; then printf 'dead: %s: NOT fully removed (it still holds something not listed before removal)\n' "$s"
  else printf 'removed: %s (%s file(s))\n' "$s" "$c"; fi
done
[ "$apply" = 1 ] && printf '%s dead store(s), %s file(s) removed\n' "$n" "$nf" || printf '%s dead store(s), %s file(s); rerun with --apply to remove them\n' "$n" "$nf"
exit 0
