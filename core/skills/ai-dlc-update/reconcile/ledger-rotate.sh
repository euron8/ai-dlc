#!/usr/bin/env bash
# ledger-rotate.sh — move CLOSED push-candidate entries out of the live ledger and into an
# archive, so the file the pull reads stays proportional to the work that is still open.
#
# WHY THIS EXISTS. The ledger is append-only by design: step 8 appends, ledger-reverify never
# edits, and a close is an ANNOTATION ("ADOPTED UPSTREAM"), never a deletion — deliberately,
# because the entry is the provenance of an upstreamed change. Nothing, however, ever moved a
# closed entry OUT. Measured on the reference consumer at v0.147.1: 2830 lines / 220 KB / 50
# entries, grown 1038 -> 1820 -> 2325 -> 2830 across 40 commits, monotonic, never once
# smaller. Only 39 entries still classify. The rest are parsed on every pull, re-rendered into
# every report, and re-read by every agent that edits the file, for zero classifier value.
#
# The cost is not theoretical: a batch of receipt edits against a 220 KB ledger is the slowest
# step in the whole update, and it grows every sprint.
#
# ROTATION IS DELIBERATELY STRICTER THAN THE SKIP RULE, and the asymmetry is the point.
# `ledger-reverify.sh` treats an entry as closed on `/ADOPTED UPSTREAM/` anywhere in it. That
# is right for SKIPPING — the cost of skipping one extra entry is one unverified row — but
# wrong for MOVING, where the cost is live work filed into an archive nobody re-reads.
#
# The phrase occurs in open entries as instruction ("annotate `ADOPTED UPSTREAM (vX, verified
# <date>)` once the grep is non-zero") and as narrative ("the sentinel ADOPTED UPSTREAM in
# v0.135.0, but ..."). Measured on the reference consumer: 47 occurrences, 32 in the annotation
# form, so 15 are not annotations. A rotation on the loose rule archives those entries.
#
# So rotation requires the ANNOTATION FORM this ledger actually writes: bolded, with the
# version immediately after — `**ADOPTED UPSTREAM (v`. Anything else stays. An entry wrongly
# kept costs one more pull to notice; an entry wrongly archived costs the work.
#
# Entry BOUNDARIES are lifted from ledger-reverify's parser unchanged: an entry is a
# top-level `- **…**` bullet or a `##`-`######` heading, and either one ENDS the entry above.
#
# THE INVARIANT THAT MAKES THIS SAFE. Closed entries are exactly the ones ledger-reverify
# already skips, so rotating them must not change its output by a single byte. Run
# ledger-reverify.sh before and after and diff the two — that is the acceptance test, and the
# fixture asserts it. The default (no --apply) writes nothing, so the comparison is free.
#
# Usage:
#   ledger-rotate.sh <ledger-path> [--archive <path>] [--apply]
#     default          report what WOULD move; write nothing
#     --apply          rewrite the ledger and append to the archive
#     --archive PATH   default: <ledger-dir>/push-candidate-ledger.archive.md
#
# Exit: 0 = reported or rotated (0 closed entries is a normal, affirmative result)
#       1 = refused: an integrity check failed and nothing was written
#       2 = usage
set -uo pipefail

# ledger_entry_shape() — THE entry-boundary rule, from lib.sh. This block used to carry its own
# copy, "lifted from ledger-reverify's parser unchanged"; within one release the label rule in
# it had already drifted. There is one boundary now.
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" || { echo "ledger-rotate: cannot source $SELF/lib.sh" >&2; exit 1; }

LEDGER="${1:-}"
[ -n "$LEDGER" ] || { echo "usage: ledger-rotate.sh <ledger-path> [--archive <path>] [--apply]" >&2; exit 2; }
[ -f "$LEDGER" ] || { echo "ledger-rotate: no ledger at '$LEDGER' — nothing to rotate." >&2; exit 0; }
shift

APPLY=0
ARCHIVE="$(dirname "$LEDGER")/push-candidate-ledger.archive.md"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)   APPLY=1; shift ;;
    --archive) ARCHIVE="${2:?--archive needs a path}"; shift 2 ;;
    *) echo "ledger-rotate: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

TMPD="$(mktemp -d)" || { echo "ledger-rotate: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$TMPD"' EXIT

# Split the ledger into KEEP and MOVE by the same boundary + closed rules ledger-reverify
# uses. Everything before the first entry boundary is the file's preamble and always stays
# (`started` stays 0 until the first boundary, and only `started && closed` moves).
# Append (`>>`) into pre-created files: awk's `>` truncates on first write per target, which
# would drop every entry but the last.
rm -f "$TMPD/keep" "$TMPD/move" "$TMPD/moved-names"
: > "$TMPD/keep"; : > "$TMPD/move"; : > "$TMPD/moved-names"
awk -v keep="$TMPD/keep" -v move="$TMPD/move" -v names="$TMPD/moved-names" "$(ledger_entry_awk)"'
  function flush(  i) {
    if (n == 0) return
    out = (started && closed) ? move : keep
    for (i = 1; i <= n; i++) print buf[i] >> out
    if (started && closed) print label >> names
    n = 0; closed = 0; label = ""
  }
  # NOT TRUNCATED. This label is what the run prints as `moved-names` — the record of which
  # entries left the live ledger. Clipping it to 70 characters, as this did, produced a name the
  # operator cannot grep back into either file. Same clip, same reason, as the one removed from
  # ledger-reverify.sh. The em-dash split stays reverify-only: unifying the two label rules
  # changes this output, which lib.sh records as a separate call.
  function open_entry(l) {
    flush(); started = 1
    sub(/^[-#][ \t]*/, "", l); gsub(/\*\*/, "", l); gsub(/`/, "", l)
    sub(/[[:space:]]+$/, "", l); label = l
  }
  { if (ledger_entry_shape($0) != "") { open_entry($0); buf[++n] = $0; next } }
  /\*\*ADOPTED UPSTREAM \(v/ { closed = 1 }
                     { buf[++n] = $0 }
  END { flush() }
' "$LEDGER"

n_move="$(grep -c . "$TMPD/moved-names" 2>/dev/null || echo 0)"
l_all="$(wc -l < "$LEDGER" | tr -d ' ')"
l_keep="$(wc -l < "$TMPD/keep" | tr -d ' ')"
l_move="$(wc -l < "$TMPD/move" | tr -d ' ')"

# INTEGRITY: every line is in exactly one output. A rotation that drops a line is worse than
# no rotation at all, so this refuses rather than reports.
if [ "$(( l_keep + l_move ))" -ne "$l_all" ]; then
  echo "ledger-rotate: REFUSED — line accounting does not balance (${l_keep} kept + ${l_move} moved != ${l_all} total). Nothing written." >&2
  exit 1
fi

if [ "$n_move" -eq 0 ]; then
  echo "ledger-rotate: 0 closed entries — nothing to rotate (${l_all} lines stay)."
  exit 0
fi

if [ "$APPLY" -eq 0 ]; then
  echo "ledger-rotate: ${n_move} closed entries would move (${l_move} of ${l_all} lines, leaving ${l_keep})."
  sed 's/^/  /' "$TMPD/moved-names"
  echo "  archive: ${ARCHIVE}"
  echo "  re-run with --apply to write. Verify after: ledger-reverify.sh output must be BYTE-IDENTICAL."
  exit 0
fi

if [ ! -f "$ARCHIVE" ]; then
  {
    echo "# Push-candidate ledger — archive"
    echo
    echo "Entries closed against upstream, rotated out of the live ledger by"
    echo "\`reconcile/ledger-rotate.sh\`. Nothing here is re-verified: an entry is archived"
    echo "only once \`ledger-reverify.sh\` already skips it. This file is provenance, not a"
    echo "worklist. Never hand-edit an entry back into the live ledger — re-file it."
    echo
  } > "$ARCHIVE"
fi
cat "$TMPD/move" >> "$ARCHIVE"
cat "$TMPD/keep" > "$LEDGER"

echo "ledger-rotate: moved ${n_move} closed entries (${l_move} lines) to ${ARCHIVE}; ledger is now ${l_keep} lines."
sed 's/^/  /' "$TMPD/moved-names"
