#!/usr/bin/env bash
# ledger-reverify-d — shard 'd' of the ledger-reverify assertion set (BL-406).
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The seed, the units, the deal and the
# reasoning all live in the sibling's run.sh; what this directory buys is a unit the pre-push pool
# can start on its own. That suite is POLE-BOUND -- its makespan tracks its single longest
# DIRECTORY, and `core/fixtures/*/run.sh` is what it globs -- and the unsharded sibling was the pole.
#
# THIS SHARD SHIPS. It carries NO `.dist-only` marker, because a shard's packaging is its
# sibling's packaging and the sibling ships: it is named in scripts/uninstall.sh's removal loop,
# in core-manifest.md and in setup-sites.md, and I74 joins those against the derived shippable set.
#
# IT EXECS UNCONDITIONALLY. There is deliberately no check that the sibling declares SHARDS: an
# older sibling that ignores `--group` runs every unit, which is correct at four times the cost,
# where such a check would turn a respelling into a green no-op. The sibling's own coverage join
# refuses if this file stops naming its shard.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree.
#
# Usage: run.sh
# Exit:  0 = every assertion in this shard holds, 1 = one regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../ledger-reverify/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling ledger-reverify/run.sh not found — shard 'd' has no assertions to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group d
