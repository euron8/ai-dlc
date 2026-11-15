#!/usr/bin/env bash
# ledger-reverify-c -- shard 'c' of the ledger-reverify fixture. A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY: the
# units, the seed and the coverage join live in the sibling's run.sh (--group c selects this shard's units).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../ledger-reverify/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling ledger-reverify/run.sh not found -- shard 'c' has nothing to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}
exec bash "$IMPL" --group c
