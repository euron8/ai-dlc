#!/usr/bin/env bash
# ledger-reverify-b -- shard 'b' of the ledger-reverify fixture. A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY: the
# units, the seed and the coverage join live in the sibling's run.sh (--group b selects this shard's units).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../ledger-reverify/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling ledger-reverify/run.sh not found -- shard 'b' has nothing to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}
exec bash "$IMPL" --group b
