#!/usr/bin/env bash
# seed.sh — build a throwaway copy of the distribution's own tree.
#
# The subject under test (`scripts/validate-enforcement-map.sh`) derives REPO_ROOT from
# its own location (`dirname "$0"/..`), so the only way to exercise it against a mutated
# tree is to give it a mutated tree to sit in. core/ + scripts/ is ~1.4 MB / 138 files;
# copying it costs milliseconds and keeps every mutation off the real repo.
#
# Prints the temp root on stdout. Caller owns cleanup.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$(cd "$HERE/../../.." && pwd)"

[ -f "$DIST/scripts/validate-enforcement-map.sh" ] || {
  echo "seed: not in a distribution tree (no scripts/validate-enforcement-map.sh at $DIST)" >&2
  exit 2
}

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/enforcement-map-sites.XXXXXX")"
mkdir -p "$ROOT"
cp -R "$DIST/core"    "$ROOT/core"
cp -R "$DIST/scripts" "$ROOT/scripts"

printf '%s\n' "$ROOT"
