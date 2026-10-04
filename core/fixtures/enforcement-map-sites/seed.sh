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
# `cp -RX` -- no extended attributes, no resource forks. The validator reads file CONTENT and
# never an xattr, so the copy is the same tree to it. What -X removes is the xattr traffic: under
# the read-set deriver's sandbox profile every xattr read is one more report in `log stream`, and
# this seed runs once per assertion inside an 8-way pool. Measured at load ~35-41 under the
# deriver's own profile, eight concurrent seed copies: `cp -R` 85-115 drop notices per rep,
# `cp -RX` 49-66, at roughly half the report volume.
# -X IS BSD-ONLY, and that is acceptable only because every consumer of this seed is `.dist-only`
# (enforcement-map-sites, -b, -c and validator-arm-selection) and never runs on a consumer's Linux.
# The sibling seeds in enforcement-map-derivations, consumer-machinery-home and
# derived-fence-binding keep `cp -R` DELIBERATELY: none of them is a pooled seed under a traced
# run, and widening a BSD-only flag to them buys nothing measured.
cp -RX "$DIST/core"      "$ROOT/core"
cp -RX "$DIST/scripts"   "$ROOT/scripts"
cp -RX "$DIST/.githooks" "$ROOT/.githooks"
# templates/ is part of the tree the validator reads, not decoration: I22 joins
# every role file's model key against templates/settings.json.template's
# aiDlcModels block. Omit it and I22's own cannot-find-the-file guard fires on
# the PRISTINE seed, which assertion 0 correctly reports as a broken fixture.
cp -RX "$DIST/templates" "$ROOT/templates"

printf '%s\n' "$ROOT"
