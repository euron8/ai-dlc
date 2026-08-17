#!/usr/bin/env bash
# Independently re-run every step-19 replacement receipt and assert it still measures what
# `replacement-receipts.tsv` claims it measures.
#
# THIS SCRIPT NO LONGER PARSES THE BATCH MARKDOWN, AND THAT IS THE POINT. It used to, which made
# two parsers of one grammar -- N copies of a grammar are N-1 chances to drift, and the drift is
# invisible because both halves keep running. `extract-receipts.sh` is the only parser; this is
# the only runner; the TSV is the seam between them.
#
# POLARITY, from ledger-reverify.sh's own `sh` dispatch and not from any header:
#   rc = 0      -> STILL-LIVE      (the defect still reproduces)  <- REQUIRED today
#   rc != 0     -> CLOSE-CANDIDATE (upstream fixed it)            <- FALSE CLOSE today
#   rc 126/127  -> NEEDS-REVIEW    (subject unresolvable)
#
# Usage: run-receipts.sh [--probe]

set -u

root=$(cd "$(dirname "$0")" && pwd)
while [ "$root" != "/" ] && [ ! -f "$root/VERSION" ]; do root=$(dirname "$root"); done
[ -f "$root/VERSION" ] || { echo "REFUSING: no VERSION marker above $0" >&2; exit 1; }

DD="$root/docs/reviews/graph-ledger-adjudication-data"
SD="${AI_DLC_S19_DIR:-$DD/step19-receipts}"
TSV="${AI_DLC_S19_OUT:-$DD/replacement-receipts.tsv}"

count_headings() { LC_ALL=C awk '/^## / && /[Pp]in [0-9]+/ {n++} END {print n+0}' "$@"; }

if [ "${1:-}" = "--probe" ]; then
  # Both directions for both refusals, seeded under mktemp, before the real corpus is read.
  P=$(mktemp -d) || exit 1
  trap 'rm -rf "$P"' EXIT
  [ "$P" != "$SD" ] || { echo "PROBE BROKEN: probe dir equals the real dir" >&2; exit 1; }
  mkdir -p "$P/d"
  printf '## Pin 999001 — `PC-PROBE`\n' > "$P/d/batch-1.md"
  hdr=$(printf 'pin\tlabel\told\tnew\trc\tnote\n')
  ok_row=$(printf '999001\tPC-PROBE\tverify: theirs_has x "y"\tverify: sh true\t0\tprobe\n')
  fail=0
  chk() { if [ "$2" = "$3" ]; then printf '  ok    %-44s exit %s\n' "$1" "$3"
          else printf '  FAIL  %-44s expected %s got %s\n' "$1" "$2" "$3"; sed 's/^/        /' "$P/log"; fail=1; fi }
  run() { AI_DLC_S19_DIR="$P/d" AI_DLC_S19_OUT="$P/t.tsv" bash "$0" >"$P/log" 2>&1; echo $?; }

  printf '%s\n%s\n' "$hdr" "$ok_row" > "$P/t.tsv"
  chk 'near-miss: a matching TSV passes' 0 "$(run)"

  rm -f "$P/t.tsv"
  chk 'B1 TSV absent' 2 "$(run)"

  printf '%s\n%s\n%s\n' "$hdr" "$ok_row" "$(printf '999002\tPC-PROBE-2\tverify: theirs_has x "y"\tverify: sh true\t0\tprobe')" > "$P/t.tsv"
  chk 'B2 TSV row count exceeds pin headings' 3 "$(run)"

  printf '%s\n%s\n' "$hdr" "$(printf '999001\tPC-PROBE\tverify: theirs_has x "y"\tverify: sh false\t0\tprobe')" > "$P/t.tsv"
  chk 'B3 receipt measures non-zero (FALSE CLOSE)' 4 "$(run)"

  printf '%s\n%s\n' "$hdr" "$(printf '999001\tPC-PROBE\tverify: theirs_has x "y"\tverify: sh true\t1\tprobe')" > "$P/t.tsv"
  chk 'B4 measured rc disagrees with the TSV' 4 "$(run)"

  [ "$fail" = 0 ] && { echo "PROBE: all arms fire in both directions"; exit 0; }
  echo "PROBE FAILED" >&2; exit 1
fi

# --- ARM B1: refuse rather than report a clean run over nothing -------------------------------
[ -f "$TSV" ] || { echo "REFUSING: $TSV absent. Run extract-receipts.sh first." >&2; exit 2; }
rows=$(LC_ALL=C awk -F'\t' 'NR>1' "$TSV" | wc -l | tr -d ' ')
[ "$rows" -gt 0 ] || { echo "REFUSING: $TSV carries no rows" >&2; exit 2; }

# --- ARM B2: the TSV must cover every pin section the batch files declare ---------------------
# An independent COUNT, not a second parser: if a batch file gained an entry that the TSV does not
# carry, a green run here would certify receipts nobody extracted.
set -- "$SD"/batch-*.md
nb=0; for f in "$@"; do [ -e "$f" ] && nb=$((nb+1)); done
[ "$nb" -gt 0 ] || { echo "REFUSING: no batch-*.md under $SD" >&2; exit 3; }
heads=$(count_headings "$@")
if [ "$rows" != "$heads" ]; then
  echo "REFUSING: $TSV has $rows row(s) but $nb batch file(s) declare $heads pin section(s)." >&2
  echo "  Re-run extract-receipts.sh; a mismatch means the TSV is stale in one direction or the other." >&2
  exit 3
fi

export DIST="$root"
export CONSUMER=/Users/n8/git/graph
export BASE=adec9ae
THEIRS=$(git -C "$DIST" rev-parse HEAD) || exit 1
export THEIRS
echo "DIST=$DIST  THEIRS=$THEIRS  BASE=$BASE"
echo "$rows receipt(s) from $nb batch file(s)"
echo

bad=0; live=0; manual=0
while IFS=$'\t' read -r pin label old new rc note; do
  case "$new" in
    "verify: manual "*)
      manual=$((manual+1))
      printf '  pin %-6s HAND-REVIEW     (manual, no predicate)  %s\n' "$pin" "${label:0:52}"
      continue ;;
  esac
  body=${new#verify: sh }
  ( cd "$DIST" && eval "$body" ) >/dev/null 2>&1
  got=$?
  case "$got" in
    0)        v="STILL-LIVE      ok" ;;
    126|127)  v="NEEDS-REVIEW    subject unresolvable" ;;
    *)        v="CLOSE-CANDIDATE **FALSE CLOSE**" ;;
  esac
  printf '  pin %-6s rc=%-4s %-32s %s\n' "$pin" "$got" "$v" "${label:0:52}"
  if [ "$got" -ne 0 ]; then bad=$((bad+1))
  elif [ "$got" != "$rc" ]; then
    printf '        DISAGREES with the TSV, which records rc=%s\n' "$rc"; bad=$((bad+1))
  else live=$((live+1)); fi
done < <(LC_ALL=C awk -F'\t' 'NR>1' "$TSV")

echo
echo "=== CONTROLS, same invocation, both directions ==="
git -C "$DIST" cat-file -e "${THEIRS}:CHANGELOG.md" 2>/dev/null
echo "  a path that EXISTS at theirs                 -> rc=$? (0 expected)"
git -C "$DIST" cat-file -e "${THEIRS}:ZZQQ-NO-SUCH-FILE" 2>/dev/null
echo "  a path that does NOT exist at theirs         -> rc=$? (non-zero expected)"

echo
echo "$live STILL-LIVE · $manual HAND-REVIEW · $bad problem(s)"
# --- ARM B3/B4: a non-zero, or a disagreement with the recorded rc, is not a result -----------
[ "$bad" -eq 0 ] || { echo "FAILED: see above. For the consumer engine rc=0 is STILL-LIVE." >&2; exit 4; }
echo "ok: every receipt measures what the TSV records"
