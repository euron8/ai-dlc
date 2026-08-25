#!/usr/bin/env bash
# Render the transient pipeline state into this project's .gitignore.
#
# WHY THIS IS A SHIPPED SCRIPT AND NOT A BLOCK INSIDE install.sh. The first version of this
# lived in the installer, and the installer is a path only a NEW consumer takes. An EXISTING
# consumer arrives through ai-dlc-update, whose apply.sh copies core files by a derived
# mapping -- so the declaration would have landed at .claude/schemas/ on every pull while the
# thing that RENDERS it stayed upstream, and the consumers that already have committed
# transient state are exactly the ones that would never have received the fix. One renderer,
# two callers: install.sh at install time, and this script by name on any pull afterwards.
#
# WHAT IT RENDERS. A marker-bounded block of ignore patterns, one per entry declared transient
# in schemas/pipeline-state-paths.json. It is a PROJECTION of that declaration and restates
# nothing: the markers, the root and the patterns all come from the file, because a second
# copy of any of them drifts silently and the symptom is a consumer committing scratch files.
# Invariant I95 in the distribution binds the declaration to the machinery that writes the
# paths, in both directions.
#
# WHAT IT DELIBERATELY DOES NOT DO: untrack anything. `git rm --cached` rewrites index state,
# and a script that runs unattended during an install has no business doing that to a
# consumer's repository. Already-tracked paths are NAMED instead, with the command to run --
# because an ignore rule does nothing whatever to a file git is already tracking, and a tool
# that printed "installed" over 138 still-committed files would be reporting success for work
# that did not happen. That was the reference consumer's actual state when this was written.
#
# EXIT STATUS: 0 when the block is in place (or was just written), 1 under --check when it is
# missing or stale, 2 when the declaration cannot be resolved or read. --check never writes,
# so it is safe to run from a gate.
set -euo pipefail

MODE="write"
PROJECT_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --root)  shift; PROJECT_ROOT="${1:-}" ;;
    -h|--help)
      echo "usage: sync-transient-ignore.sh [--check] [--root <dir>]"
      echo "  (default) refresh the managed .gitignore block from the declaration"
      echo "  --check   report whether the block is present and current; write nothing"
      exit 0 ;;
    *) echo "sync-transient-ignore.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

# RESOLVE THE ROOT BY WALKING UP FOR A MARKER, never by counting `..` hops. This script sits at
# core/scripts/ in the distribution and scripts/ai-dlc/ in a consumer, and a hop count that is
# right in one is wrong in the other -- silently, because it still resolves to a directory.
if [ -z "$PROJECT_ROOT" ]; then
  _d="$(cd "$(dirname "$0")" && pwd)"
  while [ "$_d" != "/" ]; do
    if [ -d "$_d/.git" ] || [ -f "$_d/VERSION" ]; then PROJECT_ROOT="$_d"; break; fi
    _d="$(dirname "$_d")"
  done
fi
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  echo "sync-transient-ignore.sh: could not resolve a project root (no .git or VERSION above $(dirname "$0"))" >&2
  exit 2
fi

# FOUR CANDIDATES, AND A DIFFERENT ONE RESOLVES IN EACH LAYOUT -- measured on a scratch
# install, not assumed. install.sh SPLITS what shares a parent here: core/scripts/ lands at
# scripts/ai-dlc/ and core/schemas/ lands at .claude/schemas/. So `../schemas/` resolves
# upstream and resolves to NOTHING in a consumer, where scripts/schemas/ does not exist and
# the .claude/schemas/ candidate is the one that answers. Both are listed because neither
# covers both, which is the failure invariant I33 exists to catch: a path that resolves in
# this tree can resolve nowhere in an installed one. The env override is for fixtures, which
# drive a copy from a temp directory where none of the three resolve.
_self="$(cd "$(dirname "$0")" && pwd)"
SCHEMA=""
for _c in "${AI_DLC_STATE_PATHS_SCHEMA:-}" \
          "${_self}/../schemas/pipeline-state-paths.json" \
          "${PROJECT_ROOT}/.claude/schemas/pipeline-state-paths.json" \
          "${PROJECT_ROOT}/core/schemas/pipeline-state-paths.json"; do
  [ -n "$_c" ] && [ -f "$_c" ] && { SCHEMA="$_c"; break; }
done
if [ -z "$SCHEMA" ]; then
  echo "sync-transient-ignore.sh: pipeline-state-paths.json not found (looked beside this script, then under .claude/schemas/ and core/schemas/ in $PROJECT_ROOT)" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "sync-transient-ignore.sh: jq is required to read $SCHEMA" >&2
  exit 2
fi

IG_BEGIN="$(jq -r '.block_begin // empty' "$SCHEMA")"
IG_END="$(jq -r '.block_end // empty' "$SCHEMA")"
# FAIL CLOSED ON AN EMPTY MARKER. An empty begin marker makes the awk cut below match the
# blank lines in a consumer's .gitignore and delete from the first one to the end of the file.
if [ -z "$IG_BEGIN" ] || [ -z "$IG_END" ]; then
  echo "sync-transient-ignore.sh: $SCHEMA declares an empty block marker; refusing to edit .gitignore" >&2
  exit 2
fi
PATTERNS="$(jq -r '.paths[] | select(.transient) | .ignore // empty' "$SCHEMA")"
if [ -z "$PATTERNS" ]; then
  echo "sync-transient-ignore.sh: $SCHEMA declares no transient ignore patterns; refusing to write an empty block" >&2
  exit 2
fi

GITIGNORE="$PROJECT_ROOT/.gitignore"
DESIRED="$(printf '%s\n%s\n%s' "$IG_BEGIN" "$PATTERNS" "$IG_END")"

# Extract the block as it currently stands, by the same marker pair the writer uses.
CURRENT=""
if [ -f "$GITIGNORE" ]; then
  CURRENT="$(awk -v b="$IG_BEGIN" -v e="$IG_END" '
    $0 == b { inb = 1 }
    inb == 1 { print }
    inb == 1 && $0 == e { inb = 0; exit }
  ' "$GITIGNORE")"
fi

if [ "$MODE" = "check" ]; then
  if [ -z "$CURRENT" ]; then
    echo "FAIL: $GITIGNORE carries no AI/DLC transient-state block. Run: sync-transient-ignore.sh"
    exit 1
  fi
  if [ "$CURRENT" != "$DESIRED" ]; then
    echo "FAIL: the AI/DLC transient-state block in $GITIGNORE does not match $SCHEMA."
    echo "  It is a rendered region: change the declaration, then re-run sync-transient-ignore.sh."
    diff <(printf '%s\n' "$CURRENT") <(printf '%s\n' "$DESIRED") || true
    exit 1
  fi
  echo "OK: transient-state block current ($(printf '%s\n' "$PATTERNS" | wc -l | tr -d ' ') path(s))"
  exit 0
fi

# CUT THEN APPEND, bounded at BOTH ends. The begin marker on its own would make the cut run to
# EOF and take every rule the consumer wrote after installing.
if [ -f "$GITIGNORE" ]; then
  awk -v b="$IG_BEGIN" -v e="$IG_END" '
    $0 == b { skip = 1; next }
    skip == 1 && $0 == e { skip = 0; next }
    skip == 0 { print }
  ' "$GITIGNORE" > "$GITIGNORE.ai-dlc-new"
  mv "$GITIGNORE.ai-dlc-new" "$GITIGNORE"
  [ -s "$GITIGNORE" ] && printf '\n' >> "$GITIGNORE"
fi
printf '%s\n' "$DESIRED" >> "$GITIGNORE"
echo "  .gitignore: transient-state block written ($(printf '%s\n' "$PATTERNS" | wc -l | tr -d ' ') path(s))"

# NAME WHAT IS ALREADY TRACKED. An ignore rule has no effect on a tracked file, so this is the
# difference between the rule being written and the problem being fixed.
if command -v git >/dev/null 2>&1 && git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  STILL=""
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    n="$(git -C "$PROJECT_ROOT" ls-files -- "$pat" "${pat%/}" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${n:-0}" -gt 0 ] && STILL="$STILL $pat($n)"
  done <<EOF
$PATTERNS
EOF
  if [ -n "${STILL// /}" ]; then
    echo "  NOTE: these transient paths are still TRACKED, and the ignore rule does not untrack them:"
    echo "   $STILL"
    echo "    Untrack with: git rm -r --cached <path>   (then commit). Not done here: rewriting"
    echo "    your index is the operator's call, not an installer's."
  fi
fi
