#!/usr/bin/env bash
# seed.sh — build a throwaway copy of the distribution's own tree for I43/I44.
#
# `scripts/validate-enforcement-map.sh` derives REPO_ROOT from its own location
# (`dirname "$0"/..`), so the only way to exercise it against a mutated tree is to give
# it a mutated tree to sit in. Same shape as enforcement-map-sites/seed.sh, and for the
# same reason: everything the validator READS has to be here, not just what this fixture
# mutates, or an unrelated invariant fails closed on the PRISTINE seed and assertion 0
# correctly calls the whole fixture broken.
#
#   core/       the manifest, the guard, the reconcile copy — I43's subjects
#   scripts/    the validator itself, plus install.sh/uninstall.sh — I44's subjects
#   .githooks/  I30 compares this against core/git-hooks/pre-push
#   templates/  I22 joins role model keys against settings.json.template
#
# Prints the temp root on stdout. Caller owns cleanup.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$(cd "$HERE/../../.." && pwd)"

[ -f "$DIST/scripts/validate-enforcement-map.sh" ] || {
  echo "seed: not in a distribution tree (no scripts/validate-enforcement-map.sh at $DIST)" >&2
  exit 2
}

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/consumer-machinery-home.XXXXXX")"
mkdir -p "$ROOT"
cp -R "$DIST/core"      "$ROOT/core"
cp -R "$DIST/scripts"   "$ROOT/scripts"
cp -R "$DIST/.githooks" "$ROOT/.githooks"
cp -R "$DIST/templates" "$ROOT/templates"

printf '%s\n' "$ROOT"
