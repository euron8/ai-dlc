#!/usr/bin/env bash
# wait-stale-deliverable/receipt.sh <BL-id> [<subject>] -- the backlog receipts for the batch-235
# wait-beat entries, each a behaviour of the SHIPPED wait-for-deliverable.sh driven in a mktemp world.
#
#   exit 0   the fix is present
#   exit 1   it is not
#   exit 9   the receipt cannot measure: unknown id, no subject, or its world could not be built
#
# The subject is resolved from this file's tree (core/scripts/ in the distribution, scripts/ai-dlc/
# in an installed tree), never from the caller's cwd; a second argument names another copy, which is
# how a mutant or the base revision is scored against the same receipt.
#
#   BL-549  two beats from two parent shells; the one holding `.beat-inflight` delivers and exits;
#           the other is still asleep and the marker still carries a live lease.
#   BL-566  two beats from two parent shells, no --since, armed over one seat file before it is
#           written; it is written and sealed; BOTH deliver. Three worlds at once, all must pass.
#   BL-541  --complete-repair delivers a record ending `repair-complete: serial <pass>` and does
#           NOT deliver one ending in a part remediator's `seat-complete:`.
#   BL-547  --status returns at once and creates nothing; a marker followed by trailing blank
#           lines is UNSETTLED, a finding after the marker is UNFINISHED, an absent path WAITING.
#   BL-548  a seat file edited after its marker was seen delivers with REVISED-AFTER-MARKER 1; an
#           untouched one prints none.
#
# Every concurrent beat starts in its own parent shell (`own`): two beats sharing a $PPID take the
# subject's chained-sibling return and neither sleeps nor leases, which is not the case measured.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_CODE_SESSION_ID

ID="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ="${2:-}"
if [ -z "$SUBJ" ]; then
  for c in "$HERE/../../scripts/wait-for-deliverable.sh" "$HERE/../../../scripts/ai-dlc/wait-for-deliverable.sh"; do
    [ -f "$c" ] && { SUBJ="$c"; break; }
  done
fi
[ -n "$SUBJ" ] && [ -f "$SUBJ" ] || { echo "receipt: no wait-for-deliverable.sh" >&2; exit 9; }
SUBJ="$(cd "$(dirname "$SUBJ")" && pwd)/$(basename "$SUBJ")"

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wfd-receipt.XXXXXX")" || exit 9
trap 'rm -rf "$ROOT"' EXIT
own() { bash -c '"$@"; exit $?' _ "$@"; }
ENVB=(env AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR=/nonexistent)
world() { local d; d="$(mktemp -d "$ROOT/w.XXXXXX")" || exit 9; mkdir -p "$d/_bmad-output"; printf '%s' "$d"; }

r549() {
  local d a b m e p alive holder_alive
  d="$(world)"; cd "$d" || exit 9
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=10 AI_DLC_WAIT_POLL_SECS=4 bash "$SUBJ" never.md >/dev/null 2>&1 & a=$!
  sleep 0.5
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=10 AI_DLC_WAIT_POLL_SECS=1 bash "$SUBJ" y.md >/dev/null 2>&1 & b=$!
  sleep 1; printf 'done\n' > y.md; wait "$b"; sleep 0.5
  m="$(cat _bmad-output/.beat-inflight 2>/dev/null || echo '')"; e="${m%% *}"
  alive=0; kill -0 "$a" 2>/dev/null && alive=1
  p="${m#* }"; [ "$p" = "$m" ] && p=""
  holder_alive=0; case "$p" in ''|*[!0-9]*) : ;; *) kill -0 "$p" 2>/dev/null && holder_alive=1 ;; esac
  kill "$a" 2>/dev/null; wait "$a" 2>/dev/null
  [ "$alive" = 1 ] || exit 9
  case "$e" in ''|*[!0-9]*) return 1 ;; esac
  # A live lease that names the beat which just exited is the same failure in another form: no
  # live beat stands behind it. The marker must name a holder that is still running.
  [ "$e" -gt "$(date +%s)" ] && [ "$holder_alive" = 1 ]
}

r566_one() {
  local d a b
  d="$(world)"; cd "$d" || exit 9
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=14 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_SETTLE_SECS=2 \
    bash "$SUBJ" --complete x.md > a.out 2>&1 & a=$!
  sleep 1.2
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=14 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_SETTLE_SECS=2 \
    bash "$SUBJ" --complete x.md > b.out 2>&1 & b=$!
  sleep 1.2
  printf '# h\n### F-1\nx\nseat-complete: s 1 findings=1\n' > x.md
  wait "$a"; wait "$b"
  grep -q '^DELIVERED x.md' a.out && grep -q '^DELIVERED x.md' b.out || return 1
  # The fix must not get there by keeping the join epoch alive past delivery: a later beat
  # re-armed WITHOUT --since still reads the consumed file as pre-existing (Rule 28).
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_SETTLE_SECS=2 \
    bash "$SUBJ" --complete x.md > c.out 2>&1
  ! grep -q '^DELIVERED x.md' c.out
}
r566() {
  local p1 p2 p3
  ( r566_one ) & p1=$!; ( r566_one ) & p2=$!; ( r566_one ) & p3=$!
  wait "$p1" && wait "$p2" && wait "$p3"
}

r541() {
  local d s0
  d="$(world)"; cd "$d" || exit 9; s0=$(( $(date +%s) - 30 ))
  printf '### e\n- edit: x\nrepair-complete: serial requirements\n' > rec.md
  printf '### e\n- edit: x\nseat-complete: part 3\n' > part.md
  printf '### e\n- edit: x\nrepair-complete: done\n' > bare.md
  "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=4 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_SETTLE_SECS=1 \
    bash "$SUBJ" --complete-repair --since "$s0" rec.md part.md bare.md > o.txt 2>&1 || return 1
  grep -q '^DELIVERED rec.md' o.txt || return 1
  ! grep -q '^DELIVERED part.md' o.txt && ! grep -q '^DELIVERED bare.md' o.txt
}

r547() {
  local d s0 t0 n0 n1
  d="$(mktemp -d "$ROOT/w.XXXXXX")" || exit 9; cd "$d" || exit 9; s0=$(( $(date +%s) - 30 ))
  printf 'h\nseat-complete: s\n\n  \n' > tb.md
  printf 'h\nseat-complete: s\n- finding after\n' > nl.md
  t0=$(date +%s)
  env AI_DLC_WAIT_SETTLE_SECS=60 bash "$SUBJ" --status --complete --since "$s0" tb.md nl.md absent.md > o.txt 2>&1 || return 1
  [ $(( $(date +%s) - t0 )) -le 2 ] || return 1
  [ ! -e _bmad-output ] || return 1
  grep -q '^UNSETTLED tb.md' o.txt && grep -q '^UNFINISHED nl.md' o.txt && grep -q '^WAITING   absent.md' o.txt \
    && ! grep -q '^DELIVERED' o.txt || return 1
  # The same call inside a LIVE state dir: a join epoch, a settle record, a bound the beat would
  # wipe on sight, and another beat's lease registration. Nothing in it may be written or added.
  mkdir -p _bmad-output/.wait-beats || exit 9
  printf '%s' "$s0" > _bmad-output/.wait-beats/0000000000000001.since
  printf 'abc %s' "$s0" > _bmad-output/.wait-beats/0000000000000001.settle
  printf '99' > _bmad-output/.wait-beats/.bound
  printf '%s' "$(( $(date +%s) + 60 ))" > _bmad-output/.wait-beats/.lease-1
  n0="$(find _bmad-output | wc -l | tr -d ' ')"
  : > ref.stamp; sleep 1
  env AI_DLC_WAIT_SETTLE_SECS=60 bash "$SUBJ" --status --complete --since "$s0" tb.md nl.md absent.md > o2.txt 2>&1 || return 1
  n1="$(find _bmad-output | wc -l | tr -d ' ')"
  [ "$n0" = "$n1" ] && [ -z "$(find _bmad-output -newer ref.stamp)" ] && [ "$(cat _bmad-output/.wait-beats/.bound)" = 99 ]
}

r548() {
  local d s0
  d="$(world)"; cd "$d" || exit 9; s0=$(( $(date +%s) - 30 ))
  printf 'h\nseat-complete: s\n' > rv.md; printf 'h\nseat-complete: s\n' > ok.md
  ( sleep 1.5; printf 'h\n- edit\nseat-complete: s\n' > rv.md ) &
  "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=8 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_SETTLE_SECS=2 \
    bash "$SUBJ" --complete --since "$s0" rv.md ok.md > o.txt 2>&1; wait
  grep -q '^DELIVERED rv.md' o.txt && grep -q '^REVISED-AFTER-MARKER 1 rv.md' o.txt \
    && ! grep -q 'REVISED-AFTER-MARKER [0-9]* ok.md' o.txt
}

case "$ID" in
  BL-549) r549 ;;
  BL-566) r566 ;;
  BL-541) r541 ;;
  BL-547) r547 ;;
  BL-548) r548 ;;
  *) echo "receipt: unknown id '$ID' (BL-549 BL-566 BL-541 BL-547 BL-548)" >&2; exit 9 ;;
esac
