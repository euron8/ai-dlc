#!/usr/bin/env bash
# reconcile-emit-report-b — shard 'b' of the reconcile-emit-report assertion set.
#
# THIS IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The seed, the phases, the worlds and the
# reasoning all live in the sibling's run.sh; what this directory buys is a unit the pre-push pool
# can start on its own. That suite is POLE-BOUND -- its makespan tracks its single longest
# DIRECTORY, and `core/fixtures/*/run.sh` is what it globs.
#
# THIS SHARD SHIPS. It carries NO `.dist-only` marker, because a shard's packaging is its
# sibling's packaging and the sibling ships: it is named in scripts/uninstall.sh's removal loop,
# in core-manifest.md and in setup-sites.md, and I74 joins those against the derived shippable set.
#
# THE SIBLING'S VERDICT MUST NAME THIS SHARD, or this run is exit 2. A sibling that stopped
# honouring `--group` would run shard 'a' here, print PASS for it, and leave this shard's phases
# run nowhere while every directory read green. Stdout goes to a FILE, never `$( )`, and is
# replayed whole; stderr passes straight through.
#
# Resolved as a SIBLING inside core/fixtures/, never by walking up into a core subtree.
#
# Usage: run.sh
# Exit:  0 = every assertion in this shard holds, 1 = one regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../reconcile-emit-report/run.sh"
[ -f "$IMPL" ] || {
  echo "FIXTURE ERROR: sibling reconcile-emit-report/run.sh not found — shard 'b' has no assertions to run, and a shard that runs nothing passes everything it never checked" >&2
  exit 2
}
RER_OUT="$(mktemp 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed for shard 'b'" >&2; exit 2; }
trap 'rm -f "$RER_OUT"' EXIT
bash "$IMPL" --group b > "$RER_OUT"
rc=$?
cat "$RER_OUT" || { echo "FIXTURE ERROR: could not replay shard 'b' output" >&2; exit 2; }
grep -qE "^(PASS|FAIL): .* in shard 'b' of '[a-z ]+'\.\$" "$RER_OUT" || {
  echo "FIXTURE BROKEN: the sibling's verdict does not name shard 'b' (rc=$rc) — it ran another shard or none, and shard 'b' ran nowhere" >&2
  exit 2
}
exit "$rc"
