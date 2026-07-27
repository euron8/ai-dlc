#!/usr/bin/env bash
# seed.sh — build a throwaway copy of the distribution's own tree.
#
# The subject under test (`scripts/validate-enforcement-map.sh`) derives REPO_ROOT from
# its own location (`dirname "$0"/..`), so the only way to exercise it against a mutated
# tree is to give it a mutated tree to sit in. core/ + scripts/ is ~1.4 MB / 138 files;
# copying it costs milliseconds and keeps every mutation off the real repo.
#
# `.githooks/` is staged too: I30 compares the distribution hook's syntax glob against
# the consumer hook's, and a tree missing one end makes I30 fail closed -- which reads
# here as "the pristine tree does not pass" and takes every assertion below with it.
# Anything the validator READS has to be in the seed, not just what it mutates.
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
cp -R "$DIST/core"      "$ROOT/core"
cp -R "$DIST/scripts"   "$ROOT/scripts"
cp -R "$DIST/.githooks" "$ROOT/.githooks"
# templates/ is part of the tree the validator reads, not decoration: I22 joins
# every role file's model key against templates/settings.json.template's
# aiDlcModels block. Omit it and I22's own cannot-find-the-file guard fires on
# the PRISTINE seed, which assertion 0 correctly reports as a broken fixture.
cp -R "$DIST/templates" "$ROOT/templates"

printf '%s\n' "$ROOT"
