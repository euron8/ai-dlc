#!/usr/bin/env bash
# check-sp-o-here-string-reader.sh -- exit 0 iff core/fixtures/ledger-reverify-unfalsifiable/run.sh
# contains the here-string reader line (awk `exit}` read from <<< "$sp_o"). Receipt driver for BL-867.
# Exit 1: that line is absent (open). Exit 2: the file is absent.
set -u
d="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
f="$d/core/fixtures/ledger-reverify-unfalsifiable/run.sh"
[ -f "$f" ] || { echo "check-sp-o-here-string-reader: $f is absent" >&2; exit 2; }
if grep -qF "exit}' <<< \"\$sp_o\"" "$f"; then
  exit 0
fi
exit 1
