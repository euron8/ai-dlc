#!/usr/bin/env bash
# architecture-close.sh -- the architecture step's close in one call: the changelog's record inventory,
# the regenerated architecture index, and ONE commit of those files and the architecture doc.
#
# usage: architecture-close.sh --sprint <N> [--doc docs/architecture.md] [--index docs/architecture-index.md]
#                              [--no-commit]
#
# WHAT IT WRITES. `_bmad-output/planning-artifacts/s<N>/changelog-architecture.md` gets one appended
# section `## Records (architecture-close.sh)` listing, from the merged records in that directory, each
# adversarial pass record (`verdict:` and `artifact_sha:`) and each repair record (its `- source:` entry
# count and a count per `- disposition:` value). The record files are the source; the lead's own prose
# beside it is untouched. The section is appended once: a second call finds the heading and leaves the
# file alone. Then `gen-architecture-index.js` regenerates the index, and the changelog, the index and
# the architecture doc are committed by explicit path (--no-commit stops before the commit).
#
# EXIT  0 written (and committed unless --no-commit)   2 bad arguments, no record to inventory, node or the
#       generator absent, or the commit failed. An empty inventory is a refusal, never a clean pass.

AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "architecture-close.sh: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
ROOT="$AI_DLC_ROOT"
SPRINT=""; DOC="docs/architecture.md"; INDEX="docs/architecture-index.md"; COMMIT=1
die() { echo "architecture-close: $*" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --sprint)    SPRINT="${2:-}"; shift 2 ;;
    --doc)       DOC="${2:-}"; shift 2 ;;
    --index)     INDEX="${2:-}"; shift 2 ;;
    --no-commit) COMMIT=0; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
case "$SPRINT" in ''|*[!0-9]*) die "--sprint <digits> is required (project root $ROOT)" ;; esac
[ -n "$ROOT" ] && [ -d "$ROOT" ] || die "cannot resolve the project root"
cd "$ROOT" || die "cannot enter $ROOT"
SLOT="${AI_DLC_STATE_DIR:-_bmad-output}/planning-artifacts/s$SPRINT"
CHLOG="$SLOT/changelog-architecture.md"
[ -d "$SLOT" ] || die "no sprint slot $SLOT"
GEN="$AI_DLC_SELF_DIR/gen-architecture-index.js"
[ -f "$GEN" ] || die "gen-architecture-index.js is not beside this program ($AI_DLC_SELF_DIR)"
command -v node >/dev/null 2>&1 || die "node is not on PATH"

# The inventory: every adversarial pass record and every repair record of the architecture step.
INV="$(mktemp "${TMPDIR:-/tmp}/arch-close.XXXXXX")" || die "cannot create a temporary file"
trap 'rm -f "$INV"' EXIT
n=0
for f in "$SLOT"/*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  case "$b" in
    ARCHITECTURE-SPINE-adversarial-p*.md)
      v="$(sed -n 's/^verdict: *//p' "$f" | tail -1)"; a="$(sed -n 's/^artifact_sha: *//p' "$f" | tail -1)"
      printf -- '- `%s` -- verdict: %s; artifact_sha: %s\n' "$b" "${v:-none recorded}" "$(printf '%s' "$a" | cut -c1-12)" >> "$INV"; n=$((n + 1)) ;;
    ARCHITECTURE-SPINE-*repair-p*.md|architecture-*repair-p*.md)
      s="$(grep -c '^- source:' "$f")"
      d="$(sed -n 's/^- disposition: *\([A-Za-z_-]*\).*/\1/p' "$f" | sort | uniq -c | awk '{printf "%s%s=%s", (NR > 1 ? ", " : ""), $2, $1}')"
      printf -- '- `%s` -- %s entries; dispositions: %s\n' "$b" "$s" "${d:-none recorded}" >> "$INV"; n=$((n + 1)) ;;
  esac
done
[ "$n" -gt 0 ] || die "no adversarial or repair record of the architecture step in $SLOT: nothing to inventory"

if [ -f "$CHLOG" ] && grep -q '^## Records (architecture-close.sh)$' "$CHLOG"; then
  echo "architecture-close: the changelog already carries its records section; left alone ($n records found)"
else
  [ -f "$CHLOG" ] || printf '# Changelog -- architecture step, sprint %s\n\n' "$SPRINT" > "$CHLOG" || die "cannot create $CHLOG"
  { printf '\n## Records (architecture-close.sh)\n\n'; cat "$INV"; } >> "$CHLOG" || die "cannot append to $CHLOG"
  echo "architecture-close: $n records inventoried into $CHLOG"
fi

[ -f "$DOC" ] || die "the architecture doc $DOC does not exist"
node "$GEN" --doc "$DOC" --out "$INDEX" || die "gen-architecture-index.js failed"
echo "architecture-close: index regenerated at $INDEX"

[ "$COMMIT" -eq 1 ] || exit 0
git add -- "$CHLOG" "$INDEX" "$DOC" || die "git add failed"
if git diff --cached --quiet -- "$CHLOG" "$INDEX" "$DOC"; then
  echo "architecture-close: nothing to commit"; exit 0
fi
git commit -q -m "chore(s$SPRINT): architecture validation cycle closed -- changelog records, index" -- "$CHLOG" "$INDEX" "$DOC" \
  || die "git commit failed"
echo "architecture-close: committed $(git rev-parse --short HEAD)"
exit 0
