#!/usr/bin/env bash
# BL-639 receipt. Usage: bash bl639-receipt.sh [<wait-for-deliverable.sh>]
# 0 = a --mark sealed file DELIVERS with no settle window; the same file edited above its marker
#     is NOT delivered where a bare marker beside it settles (control); a bare marker still settles.
# 1 = a property failed.  9 = the receipt could not run (no verdict, never an elapsed-time FAIL).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
SUBJ="${1:-core/scripts/wait-for-deliverable.sh}"
[ -n "${1:-}" ] || [ -f "$SUBJ" ] || SUBJ=scripts/ai-dlc/wait-for-deliverable.sh
[ -f "$SUBJ" ] || { echo "REFUSED: no subject at $SUBJ" >&2; exit 9; }
# The beats run from inside a mktemp world, so a relative subject would resolve nowhere there.
case "$SUBJ" in /*) ;; *) SUBJ="$(pwd -P)/$SUBJ" ;; esac
W="$(mktemp -d)" || exit 9
mkdir -p "$W/.git"
SI=$(( $(date +%s) - 30 ))
beat() {  # $1 = settle secs, $2 = beat secs ; rest = targets
  st="$1" bq="$2"; shift 2
  ( cd "$W" && env -u CLAUDE_CODE_SESSION_ID AI_DLC_WAIT_BEAT_SECS="$bq" AI_DLC_WAIT_SETTLE_SECS="$st" \
      AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=1 \
      AI_DLC_TEAMMATE_DIR="$W/none" AI_DLC_PROJECT_ROOT="$W" \
      bash "$SUBJ" --since "$SI" --complete "$@" ) > "$W/out" 2>&1
  brc=$?; OUT="$(cat "$W/out")"
  # A beat that did not run to a per-path verdict is no progress: refuse, never a verdict.
  case "$brc" in 0|1) : ;; *) echo "REFUSED: the beat exited $brc: $OUT" >&2; exit 9 ;; esac
  for t in "$@"; do
    case "$OUT" in *"DELIVERED $t"*|*"WAITING   $t"*|*"NON-DELIVERY $t"*) : ;; *) echo "REFUSED: no verdict for $t: $OUT" >&2; exit 9 ;; esac
  done
}
has() { case "$OUT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }
body='# requirements pm cross-1

## F-1 (major) sections: 2
- sections: 2'
printf '%s\n' "$body" > "$W/s.md"; printf '%s\n' "$body" > "$W/x.md"
printf '%s\nseat-complete: requirements pm cross-2 findings=1\n' "$body" > "$W/b.md"
bash "$SUBJ" --mark "$W/s.md" requirements pm cross-1 findings=1 >/dev/null 2>&1 || { echo "FAIL: --mark refused a finished file"; exit 1; }
bash "$SUBJ" --mark "$W/x.md" requirements pm cross-1 findings=1 >/dev/null 2>&1 || { echo "FAIL: --mark refused a finished file"; exit 1; }
case "$(tail -1 "$W/s.md")" in "seat-complete: requirements pm cross-1 sha="*" findings=1") : ;;
  *) echo "FAIL: marker spelling: $(tail -1 "$W/s.md")"; exit 1 ;; esac
awk 'NR == 3 { print "## F-1 (critical) sections: 2"; next } { print }' "$W/x.md" > "$W/x.tmp" && mv "$W/x.tmp" "$W/x.md"
rc=0
beat 600 2 s.md
has "DELIVERED s.md" || { echo "FAIL: a sealed file waited on the settle window"; rc=1; }
beat 1 3 x.md b.md
# The bare marker beside it is the control AND the legacy-fallback property: it must settle in a
# beat this long, or a seat briefed before --mark hangs every join of the pull.
if has "DELIVERED b.md"; then
  has "DELIVERED x.md" && { echo "FAIL: a file edited after its seal was delivered"; rc=1; }
else
  echo "FAIL: a bare legacy marker never settled -- the fail-open net is gone, a pre-release seat hangs"; rc=1
fi
beat 600 2 b.md
has "DELIVERED b.md" && { echo "FAIL: a bare marker skipped the settle window"; rc=1; }
[ "$rc" -eq 0 ] && echo "PASS: sealed delivers at once, broken seal is unfinished, bare marker settles"
exit "$rc"
