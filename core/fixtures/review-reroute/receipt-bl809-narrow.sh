#!/usr/bin/env bash
# BL-809 item 2 receipt (narrowing a mixed re-review). Usage: bash receipt-bl809-narrow.sh <path to partition-review-diff.sh>
# Drives --narrow, --route and --map --narrow-from over this fixture's world (world.sh), with
# validate-carried-findings.sh, artifact-path-config.sh, merge-review-shards.sh and partition-document.sh
# beside the given script. The MIXED delta edits rebalancer/engine.py and rebalancer/tests/test_engine.py.
#   (a) a CODE finding `Files: rebalancer/engine.py` + an EVIDENCE finding -> NARROW engine.py, RESIDUE the test
#   (b) the CODE finding names a file outside the delta, the EVIDENCE finding's Files: names engine.py -> FULL
#   (c) the CODE finding names only a file outside the delta (an empty named set)                        -> FULL
#   (d) a second CODE finding carries no Files: line                                                      -> FULL
#   (e) an EVIDENCE|BOOKKEEPING prior over a records-only delta -> --route still answers ROUTE
#   (f) over MIXED_APP (MIXED plus a web/app.js edit), --map --narrow-from a prior naming web/app.js (2 parts,
#       as flagless, a different map) merges; the same manifest with its narrow-from line dropped is REFUSED
# 0 = every case answered as above. 1 = a case did not. 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] || { echo "REFUSED: usage: bash receipt-bl809-narrow.sh <path to partition-review-diff.sh>" >&2; exit 9; }
P="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
SD="$(dirname "$P")"; HERE="$(cd "$(dirname "$0")" && pwd)"
for f in validate-carried-findings.sh artifact-path-config.sh merge-review-shards.sh partition-document.sh; do
  [ -f "$SD/$f" ] || { echo "REFUSED: $f is not beside $P" >&2; exit 9; }
done
GR=""; PR=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  for c in "$d/core/skills/ai-dlc/artifact-path-grammar.md" "$d/.claude/skills/ai-dlc/artifact-path-grammar.md"; do [ -f "$c" ] && { GR="$c"; PR="$d"; break 2; }; done
  d="$(dirname "$d")"
done
[ -n "$GR" ] || { echo "REFUSED: no artifact-path-grammar.md above the receipt" >&2; exit 9; }
W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl809-narrow.XXXXXX")" || exit 9
trap 'rm -rf "$W"' EXIT
. "$HERE/world.sh" || exit 9
rr_world "$W" "$GR" || exit 9
R="$W/repo"; B0="$(rr_ref "$W" B0)"; S="$(rr_ref "$W" MIXED)"; TAB="$(printf '\t')"
[ -n "$S" ] && [ -f "$R/docs/reviews/s1/1-code-review.md" ] || { echo "REFUSED: world.sh seeds no MIXED delta or no in-repo prior" >&2; exit 9; }
fails=0
fail() { echo "FAIL $1: $(head -2 "$W/o" | tr '\n' ' ')"; fails=$((fails + 1)); }
n() { bash "$P" --narrow "$R" "$W/$1" "$S" --exclude-captures "$W/captures" > "$W/o" 2>&1; echo $?; }
[ "$(n nprior-a.md)" = 0 ] && [ "$(cat "$W/o")" = "NARROW:${TAB}rebalancer/engine.py
RESIDUE:${TAB}rebalancer/tests/test_engine.py" ] || fail a
[ "$(n nprior-b.md)" = 1 ] && grep -q '^FULL: ' "$W/o" || fail b
[ "$(n nprior-c.md)" = 1 ] && grep -q '^FULL: ' "$W/o" || fail c
[ "$(n nprior-d.md)" = 1 ] && grep -q '^FULL: ' "$W/o" || fail d
bash "$P" --route "$R" "$W/prior-evidence.md" "$(rr_ref "$W" RECORDS)" --exclude-captures "$W/captures" > "$W/o" 2>&1
[ "$?" = 0 ] && grep -q '^ROUTE: ' "$W/o" || fail e
SA="$(rr_ref "$W" MIXED_APP)"
[ -n "$SA" ] && [ -f "$R/docs/reviews/s1/nprior-app.md" ] || { echo "REFUSED: world.sh seeds no MIXED_APP delta or no nprior-app prior" >&2; exit 9; }
SH="$R/docs/reviews/s1/shards/1-code-review-${SA:0:12}-p2"; OUT="$R/docs/reviews/s1/1-code-review-p2.md"
fok=0
if bash "$P" --map "$R" "$B0" "$SA" --min-files 2 --narrow-from "$R/docs/reviews/s1/nprior-app.md" --shard-dir "$SH" > "$W/o" 2>&1; then
  for k in $(cut -f1 "$W/o") cross; do rr_nshard "$SH" "$k" "$SA"; done
  AI_DLC_PROJECT_ROOT="$PR" bash "$SD/merge-review-shards.sh" "$SH" --gate code-review --out "$OUT" > "$W/o" 2>&1
  if [ "$?" = 0 ] && grep -q '^MERGED: ' "$W/o"; then
    rm -f "$OUT"; grep -v "^narrow-from${TAB}" "$SH/.manifest" > "$W/m" && cp "$W/m" "$SH/.manifest"
    AI_DLC_PROJECT_ROOT="$PR" bash "$SD/merge-review-shards.sh" "$SH" --gate code-review --out "$OUT" > "$W/o" 2>&1
    [ "$?" = 2 ] && grep -q '^REFUSED: ' "$W/o" && [ ! -e "$OUT" ] && fok=1
  fi
fi
[ "$fok" = 1 ] || fail f
[ "$fails" -eq 0 ] || exit 1
exit 0
