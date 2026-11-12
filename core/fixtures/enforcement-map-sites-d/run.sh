#!/usr/bin/env bash
# enforcement-map-sites-d — the `eq` group of the enforcement-map-sites assertion set.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The assertions, the seed and the
# reasoning all live in the sibling's run.sh. This directory holds the FULL-RUN equivalence
# twins (eq-pass, eq-refuse, eq-usage): four full validator runs and three command-line
# starts that shard 'a' carried beside its pool, which put them on the suite's pole. The
# `eq` group is not a dealt shard: it is dealt no assertions and runs the seed and those
# twins only.
#
# Shard 'a' fails the build if this driver is missing, so deleting this file cannot quietly
# drop the twins. Resolved as a SIBLING inside core/fixtures/, never by walking up into a
# core subtree, the same resolution every shard driver uses (the one I33 permits).
#
# Usage: run.sh
# Exit:  0 = every equivalence cell holds, 1 = one regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../enforcement-map-sites/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling enforcement-map-sites/run.sh not found — the eq group has no assertions to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group eq
