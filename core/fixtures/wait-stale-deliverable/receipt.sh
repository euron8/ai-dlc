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
#   BL-599  --dispatch <agentId> resolves through meta.json to the ledger ts; a --since 27 s after
#           it is refused, the dispatch's own time delivers a write made between the two.
#   BL-576  a beat armed from a subdirectory of the project writes its state under the project root,
#           not under the subdirectory; the same beat from the root reaches the same place.
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
# ORDERING, NOT CLOCK. Each receipt used to place one beat before another with a fixed `sleep`; a
# loaded box reads that as red or, worse, as a different interleaving. `until_cond` polls a
# condition on a 0.02s tick (bounded at 10s, then the receipt cannot measure: exit 9), and the
# conditions are the subject's own records: a beat's lease marker, and the counter it charges
# just before it enters its poll sleep.
until_cond() { local n=500; while [ "$n" -gt 0 ]; do "$@" && return 0; sleep 0.02; n=$((n - 1)); done; return 1; }
has_marker() { [ -s _bmad-output/.beat-inflight ]; }
key16() { printf '%s' "$1" | cksum | tr -d ' \t' | cut -c1-16; }
counter_eq() { [ "$(cat "_bmad-output/.wait-beats/$(key16 "$1")" 2>/dev/null)" = "$2" ]; }
world() { local d; d="$(mktemp -d "$ROOT/w.XXXXXX")" || exit 9; mkdir -p "$d/_bmad-output"; printf '%s' "$d"; }

r549() {
  local d a b m e p alive holder_alive
  d="$(world)"; cd "$d" || exit 9
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=10 AI_DLC_WAIT_POLL_SECS=4 AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" never.md >/dev/null 2>&1 & a=$!
  until_cond has_marker || exit 9
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=10 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" y.md >/dev/null 2>&1 & b=$!
  until_cond counter_eq y.md 1 || exit 9
  printf 'done\n' > y.md; wait "$b"
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
    AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --complete x.md > a.out 2>&1 & a=$!
  until_cond counter_eq x.md 1 || return 1
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=14 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_SETTLE_SECS=2 \
    AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --complete x.md > b.out 2>&1 & b=$!
  until_cond counter_eq x.md 2 || return 1
  printf '# h\n### F-1\nx\nseat-complete: s 1 findings=1\n' > x.md
  wait "$a"; wait "$b"
  grep -q '^DELIVERED x.md' a.out && grep -q '^DELIVERED x.md' b.out || return 1
  # The fix must not get there by keeping the join epoch alive past delivery: a later beat
  # re-armed WITHOUT --since still reads the consumed file as pre-existing (Rule 28).
  own "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_SETTLE_SECS=2 \
    AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --complete x.md > c.out 2>&1
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
    AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --complete-repair --since "$s0" rec.md part.md bare.md > o.txt 2>&1 || return 1
  grep -q '^DELIVERED rec.md' o.txt || return 1
  ! grep -q '^DELIVERED part.md' o.txt && ! grep -q '^DELIVERED bare.md' o.txt
}

# "RETURNS AT ONCE" IS READ AS "NEVER ENTERED A SLEEP", NOT AS A NUMBER OF SECONDS. The subject's
# only `sleep` is its poll loop's, so a recording `sleep` first on PATH answers the question as a
# yes/no fact, whatever the box's load. The stub is shown to record (one `sleep 0` through the same
# PATH) before its empty log is read as an absence; a stub that never ran cannot pass as a beat
# that never slept.
r547() {
  local d s0 n0 n1 sb
  d="$(mktemp -d "$ROOT/w.XXXXXX")" || exit 9; cd "$d" || exit 9; s0=$(( $(date +%s) - 30 ))
  printf 'h\nseat-complete: s\n\n  \n' > tb.md
  printf 'h\nseat-complete: s\n- finding after\n' > nl.md
  sb="$ROOT/stub547"; mkdir -p "$sb/bin" || exit 9; : > "$sb/log"
  printf '#!%s\nprintf "%%s\\n" "$*" >> "%s"\nexec "%s" "$@"\n' "$(command -v bash)" "$sb/log" "$(command -v sleep)" > "$sb/bin/sleep" || exit 9
  chmod +x "$sb/bin/sleep" || exit 9
  env PATH="$sb/bin:$PATH" sleep 0 || exit 9
  [ "$(awk 'END { print NR }' "$sb/log")" = 1 ] || exit 9
  : > "$sb/log"
  env PATH="$sb/bin:$PATH" AI_DLC_WAIT_SETTLE_SECS=60 AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --status --complete --since "$s0" tb.md nl.md absent.md > o.txt 2>&1 || return 1
  [ ! -s "$sb/log" ] || return 1
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
  env AI_DLC_WAIT_SETTLE_SECS=60 AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --status --complete --since "$s0" tb.md nl.md absent.md > o2.txt 2>&1 || return 1
  n1="$(find _bmad-output | wc -l | tr -d ' ')"
  [ "$n0" = "$n1" ] && [ -z "$(find _bmad-output -newer ref.stamp)" ] && [ "$(cat _bmad-output/.wait-beats/.bound)" = 99 ]
}

r548() {
  local d s0
  d="$(world)"; cd "$d" || exit 9; s0=$(( $(date +%s) - 30 ))
  printf 'h\nseat-complete: s\n' > rv.md; printf 'h\nseat-complete: s\n' > ok.md
  ( until_cond counter_eq rv.md 1; printf 'h\n- edit\nseat-complete: s\n' > rv.md ) &
  "${ENVB[@]}" AI_DLC_WAIT_BEAT_SECS=8 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_SETTLE_SECS=2 \
    AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --complete --since "$s0" rv.md ok.md > o.txt 2>&1; wait
  grep -q '^DELIVERED rv.md' o.txt && grep -q '^REVISED-AFTER-MARKER 1 rv.md' o.txt \
    && ! grep -q 'REVISED-AFTER-MARKER [0-9]* ok.md' o.txt
}

# A forward-dated --since is refused against the dispatch it names; the dispatch's own time is the
# control, and a write between the two is DELIVERED when the join starts at the dispatch.
r599() {
  local d e tdir
  d="$(world)"; cd "$d" || exit 9; e=$(( $(date +%s) - 90 ))
  printf '{"v":1,"ts":"%s","name":"remediator","role":"remediator","tool_use_id":"toolu_R599"}\n' \
    "$(date -u -r "$e" +%Y-%m-%dT%H:%M:%SZ)" > _bmad-output/spawn-ledger.jsonl
  tdir="$d/sub"; mkdir -p "$tdir"
  printf '{"agentType":"remediator","toolUseId":"toolu_R599"}' > "$tdir/agent-a599.meta.json"
  printf 'x\n' > r.md; touch -t "$(date -r $(( e + 5 )) +%Y%m%d%H%M.%S)" r.md
  env AI_DLC_TEAMMATE_DIR="$tdir" AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --status --dispatch a599 --since $(( e + 27 )) r.md > f.txt 2>&1
  [ $? -eq 64 ] && grep -q '27 s after' f.txt || return 1
  env AI_DLC_TEAMMATE_DIR="$tdir" AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --status --dispatch a599 --since "$e" r.md > c.txt 2>&1 || return 1
  grep -q '^DELIVERED r.md' c.txt || return 1
  env AI_DLC_TEAMMATE_DIR="$tdir" AI_DLC_PROJECT_ROOT="$PWD" bash "$SUBJ" --status --dispatch a599 r.md > n.txt 2>&1 || return 1
  grep -q '^DELIVERED r.md' n.txt
}

# A beat armed from a subdirectory of the project lands its state under the PROJECT ROOT, not under
# the subdirectory. The world has a `.git` marker and the subject is COPIED into it, so the walk
# from the script's own directory resolves to the world and not to the real repository. No
# AI_DLC_PROJECT_ROOT and no AI_DLC_STATE_DIR are set. The control is the same beat from the root.
r576() {
  local d p s lease m
  d="$(mktemp -d "$ROOT/w.XXXXXX")" || exit 9
  mkdir -p "$d/.git" "$d/scripts" "$d/shards/p1" || exit 9
  cp "$SUBJ" "$d/scripts/wait-for-deliverable.sh" || exit 9
  ( cd "$d/shards/p1" && own env AI_DLC_WAIT_BEAT_SECS=1 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 \
      AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR=/nonexistent CLAUDE_PROJECT_DIR= \
      bash "$d/scripts/wait-for-deliverable.sh" never.md ) >/dev/null 2>&1
  [ ! -e "$d/shards/p1/_bmad-output" ] || return 1
  [ -d "$d/_bmad-output/.wait-beats" ] || return 1
  rm -rf "$d/_bmad-output"
  ( cd "$d" && own env AI_DLC_WAIT_BEAT_SECS=1 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 \
      AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR=/nonexistent CLAUDE_PROJECT_DIR= \
      bash "$d/scripts/wait-for-deliverable.sh" never.md ) >/dev/null 2>&1
  [ -d "$d/_bmad-output/.wait-beats" ] && [ ! -e "$d/shards/p1/_bmad-output" ] || return 1
  # The LEASE is the owed property, and the EXIT trap releases it, so it is read while a beat from
  # the subdirectory is still asleep: it must be at the root, where the stop hook reads it.
  rm -rf "$d/_bmad-output"
  ( cd "$d/shards/p1" && exec bash -c '"$@"; exit $?' _ env AI_DLC_WAIT_BEAT_SECS=8 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 \
      AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR=/nonexistent CLAUDE_PROJECT_DIR= \
      bash "$d/scripts/wait-for-deliverable.sh" never.md ) >/dev/null 2>&1 & p=$!
  # Poll for the lease rather than sleeping a fixed time: under load a fixed sleep only reads red.
  # The beat is a CHILD of the wrapper `$p` (the trailing `exit $?` keeps bash from exec-ing it),
  # so it is stopped by the pid its own lease names, then the wrapper is reaped.
  lease=0; m=""
  for _ in $(seq 1 500); do
    [ -s "$d/_bmad-output/.beat-inflight" ] && { lease=1; m="$(cat "$d/_bmad-output/.beat-inflight")"; break; }
    sleep 0.02
  done
  case "${m#* }" in ''|*[!0-9]*) : ;; *) kill "${m#* }" 2>/dev/null ;; esac
  kill "$p" 2>/dev/null; wait "$p" 2>/dev/null
  [ "$lease" = 1 ] || return 1
  # Two shard dirs arm the same RELATIVE name: two deliverables, so two join records, not one.
  rm -rf "$d/_bmad-output"; mkdir -p "$d/shards/p2" || exit 9
  for s in p1 p2; do
    ( cd "$d/shards/$s" && own env AI_DLC_WAIT_BEAT_SECS=1 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 \
        AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR=/nonexistent CLAUDE_PROJECT_DIR= \
        bash "$d/scripts/wait-for-deliverable.sh" 1.md ) >/dev/null 2>&1
  done
  [ "$(find "$d/_bmad-output/.wait-beats" -name '*.since' 2>/dev/null | wc -l | tr -d ' ')" = 2 ] || return 1
  # An ABSOLUTE AI_DLC_STATE_DIR is used as given, never joined onto the root.
  ( cd "$d/shards/p1" && own env AI_DLC_WAIT_BEAT_SECS=1 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 \
      AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR=/nonexistent CLAUDE_PROJECT_DIR= \
      AI_DLC_STATE_DIR="$d/abs-state" bash "$d/scripts/wait-for-deliverable.sh" never.md ) >/dev/null 2>&1
  [ -d "$d/abs-state/.wait-beats" ]
}

case "$ID" in
  BL-576) r576 ;;
  BL-599) r599 ;;
  BL-549) r549 ;;
  BL-566) r566 ;;
  BL-541) r541 ;;
  BL-547) r547 ;;
  BL-548) r548 ;;
  *) echo "receipt: unknown id '$ID' (BL-549 BL-566 BL-541 BL-547 BL-548 BL-599 BL-576)" >&2; exit 9 ;;
esac
