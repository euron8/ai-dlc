#!/usr/bin/env bash
# BL-902 receipt. Usage: bash core/fixtures/backlog-receipt-binding/receipt-bl902.sh   (run from the repo root)
# Six docs/backlog.archive.md LANDED lines once cited a pre-squash intermediate commit that is not on
# main. Each was re-anchored to its release squash. For each entry, located by its HEADING (never by a
# line number), this reads the entry's LANDED line, extracts the sha with the anchored form of
# scripts/backlog-rotate.sh (so an inner `PARTIAL (..., verified <sha>)` is never taken), and requires:
#   - the line's version is the version this table expects for that entry;
#   - the sha resolves to a commit;
#   - the sha is an ancestor of HEAD;
#   - the subject of that commit begins with the line's version (`0.862.0 ...`), so an on-main sha
#     from a different release does not pass.
# 0 = all six hold, and exactly six entries were checked.
# 1 = some entry cites an unresolvable sha, a non-ancestor, or a commit of another release.
# 9 = the anchor is absent: an entry heading, or its LANDED line, was not found.
# 2 = the receipt could not run (no git-env seam, not at the distribution root).
set -uo pipefail
# The pre-push hook exports GIT_DIR; the git calls below must act on the repository of the cwd.
r902_seam() { # walk up from $1 for the git-env seam; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/fixtures/lib/preamble.sh" ]; then printf '%s\n' "$d/core/fixtures/lib/preamble.sh"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
_PRE="$(r902_seam "$(cd "$(dirname "$0")" && pwd)")" || _PRE=""
[ -n "$_PRE" ] && [ -f "$_PRE" ] || { echo "REFUSED: no git-env seam core/fixtures/lib/preamble.sh above $0" >&2; exit 2; }
. "$_PRE"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ARCH=docs/backlog.archive.md
[ -f scripts/backlog-rotate.sh ] || { echo "REFUSED: run from the distribution root" >&2; exit 2; }

# The entries and the version each LANDED line must carry.
ENTRIES="BL-702 v0.845.0
BL-647 v0.862.0
BL-662 v0.862.0
BL-670 v0.862.0
BL-664 v0.862.0
BL-689 v0.862.0"

# ANCHOR FIRST: every heading is present before any sha is judged.
while read -r id ver; do
  [ -n "$id" ] || continue
  grep -qF "## $id — " "$ARCH" || { echo "ANCHOR ABSENT: no heading '## $id — ' in $ARCH" >&2; exit 9; }
done <<<"$ENTRIES"

checked=0; bad=0
while read -r id ver; do
  [ -n "$id" ] || continue
  # The entry's first LANDED line: from its heading to the next heading.
  ann="$(awk -v h="## $id — " 'index($0, h) == 1 {on = 1; next} on && /^## / {exit} on && /^(<br>)?\*\*LANDED \(/ {print; exit}' "$ARCH")"
  [ -n "$ann" ] || { echo "ANCHOR ABSENT: $id has no LANDED line" >&2; exit 9; }
  # The sha, by the anchored form of scripts/backlog-rotate.sh (its SHA= line), verbatim.
  sha="$(printf '%s\n' "$ann" | sed -n 's/^\(<br>\)\{0,1\}\*\*LANDED (v[^,]*, verified \([0-9a-f]\{7,\}\)[^0-9a-f].*/\2/p')"
  lver="$(printf '%s\n' "$ann" | sed -n 's/^\(<br>\)\{0,1\}\*\*LANDED (\(v[^,]*\), verified [0-9a-f]\{7,\}[^0-9a-f].*/\2/p')"
  [ -n "$sha" ] && [ -n "$lver" ] || { echo "ANCHOR ABSENT: $id LANDED line does not parse" >&2; exit 9; }
  checked=$((checked + 1))
  if [ "$lver" != "$ver" ]; then
    echo "FAIL: $id LANDED version $lver, expected $ver" >&2; bad=1; continue
  fi
  if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
    echo "FAIL: $id cites $sha, which does not resolve to a commit" >&2; bad=1; continue
  fi
  if ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
    echo "FAIL: $id cites $sha, which is not an ancestor of HEAD" >&2; bad=1; continue
  fi
  subj="$(git log -1 --format=%s "$sha" 2>/dev/null)" || subj=""
  case "$subj" in
    "${ver#v} "*) echo "ok    $id $ver $sha" ;;
    *) echo "FAIL: $id cites $sha, whose subject does not begin with ${ver#v}: $subj" >&2; bad=1 ;;
  esac
done <<<"$ENTRIES"

[ "$checked" -eq 6 ] || { echo "FAIL: checked $checked entries, expected 6" >&2; exit 1; }
[ "$bad" -eq 0 ] || exit 1
exit 0
