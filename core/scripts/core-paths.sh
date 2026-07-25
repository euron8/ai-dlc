#!/usr/bin/env bash
set -uo pipefail

# core-paths.sh — resolve whether a project-relative path is upstream-owned CORE.
#
# WHY THIS EXISTS. Check 16 (stub audit) greps changed hot-path files for stub
# markers and requires four elements in the surrounding comment block, one of
# which is an `Item N` resolvable in the CONSUMER's carry-over-backlog.md. A
# core-owned file can satisfy none of them: it cannot carry a consumer's backlog
# item number, and `ai-dlc-core-guard.sh` DENIES the in-place edit that would add
# one -- there is no overrides/ shadow and no extensions/ entry for a hook or a
# validator. So a core file caught by the marker regex was a gate FAIL with no
# clearing path short of forking core (Rule 27 forbids it) or an operator waiver
# on every pull. Observed on the reference consumer at ai-dlc 0.156.0: a prose
# comment in `reconcile/apply.sh` reading "Phase 3's layer-drift.sh does NOT
# belong here" matched `Phase [0-9]` and failed a §6 gate four times. 19
# core-distributed hot-path files carry 45 such marker lines; each one is the
# same failure waiting for a pull that touches it.
#
# Stub discipline for core files is not abandoned -- it MOVES to the distribution
# repo, where the edit and the backlog item number both exist. This resolver is
# what lets the consumer-side check say "not mine" mechanically instead of the
# adjudicator being trusted to eyeball it.
#
# usage:
#   core-paths.sh --is-core <project-relative-path> [<manifest>]
#   core-paths.sh --list [<manifest>]
#
# exit (--is-core):
#   0 = the path IS core-manifest-owned
#   1 = the path is NOT core (consumer-authored, or a layer/doc/source path)
#   2 = cannot determine -- no readable manifest in either layout. NEVER degrades
#       to a 0 or a 1: "no manifest found" and "not core" are different answers
#       and a caller that cannot tell them apart will exempt the whole tree.
#
# exit (--list): 0 with one consumer-relative glob per line, 2 if unparseable.
#
# The path set is DERIVED from core-manifest.md (fallback: setup-sites.md's
# I5-synced copy). Nothing is hand-listed here.
#
# ON THE DUPLICATE PARSER. `parse_manifest()` and `to_consumer_glob()` below are
# byte-identical copies of the same functions in `hooks/ai-dlc-core-guard.sh`,
# and `validate-enforcement-map.sh` FAILS the build if they ever diverge. The
# copy is deliberate and the binding is what makes it safe: the guard must stay
# self-contained, because a guard that sources a helper stops denying core writes
# entirely if that helper is missing from a partial install -- it fails open, and
# a silently-disabled write guard is worse than a duplicated 25-line parser. Two
# copies bound byte-for-byte cannot drift; one copy with a fragile load path can
# vanish.

usage() {
  echo "usage: core-paths.sh --is-core <path> [<manifest>]" >&2
  echo "       core-paths.sh --list [<manifest>]" >&2
}

# --- BEGIN SHARED WITH hooks/ai-dlc-core-guard.sh (byte-identical; I20) -------
parse_manifest() {   # <file> -> raw core_manifest entries, one per line
  local f="$1"
  [ -r "$f" ] || return 1
  awk '
    /^core_manifest:[ \t]*$/ { inlist=1; next }
    inlist && /^[ \t]*-[ \t]+/ {
      line=$0
      sub(/^[ \t]*-[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      next
    }
    inlist && /^[^ \t]/ { inlist=0 }     # dedent (incl. a closing ``` fence) ends the list
  ' "$f"
}

to_consumer_glob() {  # <manifest entry> -> consumer-relative glob
  local e="${1#core/}"                    # setup-sites.md form carries a core/ prefix
  case "$e" in
    team-roles/*)     printf '.claude/%s\n' "$e" ;;
    hooks/*)          printf '.claude/%s\n' "$e" ;;   # hooks live at .claude/hooks/, outside the skill dir
    scripts/*)        printf '%s\n' "$e" ;;           # scripts/ai-dlc/* is at the project root, not under .claude/
    fixtures/*)       printf 'tests/%s\n' "$e" ;;     # install.sh copies core/fixtures/<n>/ to tests/fixtures/<n>/
    git-hooks/*)      printf '.githooks/%s\n' "${e#git-hooks/}" ;;  # .githooks/, where core.hooksPath points
    session-driver/*) printf '.claude/%s\n' "$e" ;;   # machinery, outside the skill dir
    schemas/*)        printf '.claude/%s\n' "$e" ;;   # machinery, outside the skill dir
    skills/*)         printf '.claude/%s\n' "$e" ;;   # ai-dlc/, ai-dlc-setup/ and ai-dlc-update/ all sit under .claude/skills/
    *)                printf '.claude/skills/ai-dlc/%s\n' "$e" ;;
  esac
}
# --- END SHARED WITH hooks/ai-dlc-core-guard.sh -------------------------------

MODE="${1:-}"
case "$MODE" in
  --is-core|--list) ;;
  *) usage; exit 2 ;;
esac

TARGET=""
if [ "$MODE" = "--is-core" ]; then
  TARGET="${2:-}"
  [ -n "$TARGET" ] || { usage; exit 2; }
  EXPLICIT="${3:-}"
else
  EXPLICIT="${2:-}"
fi

# Manifest resolution. An explicit argument wins; otherwise try the consumer
# layout first, then the distribution layout, then each layout's setup-sites.md
# copy. Both layouts are searched because this script runs in both: installed as
# `scripts/ai-dlc/core-paths.sh` in a consumer, and read straight out of
# `core/scripts/` by the distribution's own fixtures and gates.
CANDIDATES=""
if [ -n "$EXPLICIT" ]; then
  CANDIDATES="$EXPLICIT"
else
  CANDIDATES="$(printf '%s\n' \
    ".claude/skills/ai-dlc/core-manifest.md" \
    "core/skills/ai-dlc/core-manifest.md" \
    ".claude/skills/ai-dlc-update/reconcile/setup-sites.md" \
    "core/skills/ai-dlc-update/reconcile/setup-sites.md")"
fi

RAW_ENTRIES=""
USED=""
while IFS= read -r c; do
  [ -n "$c" ] || continue
  RAW_ENTRIES="$(parse_manifest "$c" 2>/dev/null || true)"
  if [ -n "$RAW_ENTRIES" ]; then USED="$c"; break; fi
done <<EOF
$CANDIDATES
EOF

if [ -z "$RAW_ENTRIES" ]; then
  echo "core-paths: FAIL -- no parseable core_manifest list found. Tried:" >&2
  printf '%s\n' "$CANDIDATES" | sed 's/^/  /' >&2
  echo "  Refusing to answer. 'no manifest' is not 'not core': a caller that reads" >&2
  echo "  this as a clean negative would treat every path as consumer-owned." >&2
  exit 2
fi

CORE_GLOBS=""
while IFS= read -r e; do
  [ -n "$e" ] || continue
  CORE_GLOBS="${CORE_GLOBS}$(to_consumer_glob "$e")
"
done <<EOF
$RAW_ENTRIES
EOF

if [ "$MODE" = "--list" ]; then
  printf '%s' "$CORE_GLOBS"
  exit 0
fi

# Normalise the probe the same way the guard does: strip a leading ./ so
# `./scripts/ai-dlc/verdict.sh` and `scripts/ai-dlc/verdict.sh` agree.
REL="${TARGET#./}"

while IFS= read -r g; do
  [ -n "$g" ] || continue
  # shellcheck disable=SC2254
  case "$REL" in
    $g) echo "core: ${REL} (matches core-manifest glob '${g}' via ${USED})"; exit 0 ;;
  esac
done <<EOF
$CORE_GLOBS
EOF

echo "not-core: ${REL} (no core-manifest glob matches; manifest read from ${USED})"
exit 1
