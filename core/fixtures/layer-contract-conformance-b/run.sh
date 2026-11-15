#!/usr/bin/env bash
# layer-contract-conformance-b — shard 'b' of the layer-contract-conformance assertion set: it execs the sibling
# run.sh with `--group b`, which runs the in-process-versus-CLI twin. The control arms and the consumer-SKIP arm run in
# shard 'a' only.
#
# THIS SHARD IS `.dist-only`, AND SO IS ITS SIBLING: the subject, validate-enforcement-map.sh, is not shipped.
# I116 refuses a shipped user of a sibling that does not ship, so the two must move together. The sibling is
# resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree (I33).
#
# Usage: run.sh
# Exit:  0 = every assertion in this shard holds, 1 = one regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../layer-contract-conformance/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling layer-contract-conformance/run.sh not found — shard 'b' has no assertions to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}

exec bash "$IMPL" --group b
