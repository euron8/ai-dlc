#!/usr/bin/env bash
# readset-stage1-run.sh -- run ONE stage-1 sandbox trace of the five subjects and record it.
#
# Usage: bash scripts/readset-stage1-run.sh <RUN_DIR>
#
# DISTRIBUTION-ONLY. A stage-1 run is a measurement of the sandbox tracer's completeness on this
# repo's heaviest fixtures, scored by scripts/readset-stage1-verdict.sh over the LAST THREE runs
# this wrapper recorded. It never changes the map: the deriver's write is undone byte-identically.
#
# LAYOUT, and the verdict script reads exactly this:
#   $RUN_DIR/root/        the deriver's AI_DLC_READSET_TRACE_ROOT (t/ w/ m/)
#   $RUN_DIR/deriver.log  the deriver's stdout+stderr
#   $RUN_DIR/rc           the deriver's exit status
#   $RUN_DIR/load.tsv     epoch<TAB>1-min load, every 15 s, from before the deriver starts to after
#   $RUN_DIR/map.before   the map snapshot the restore copies back
# Everything the wrapper writes sits BESIDE root/, never under it: the deriver `rm -rf`s its trace
# root before it starts, and that was measured to unlink a file still held open there.
#
# THE LEDGER is append-only and outside every root:
#   $(git rev-parse --git-common-dir)/ai-dlc-readset-stage1.ledger
#   (AI_DLC_READSET_STAGE1_LEDGER overrides it, for the fixture)
# one line per run whose deriver was STARTED: RUN_DIR<TAB>rc<TAB>start-epoch<TAB>end-epoch<TAB>HEAD.
# A killed run is recorded too, with rc `killed` -- the verdict refuses it, and leaving it out
# would let the next three good runs read as consecutive when they were not. A refusal BEFORE the
# deriver starts (worktree, dirty tree, RUN_DIR exists) records nothing, because nothing ran.
#
# Exit: the deriver's status; 2 on a refusal before the deriver starts; 3 when the map could not
# be restored byte-identically (the checkout is then dirty and says so).
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR 2>/dev/null

# THE SUBJECTS. scripts/readset-stage1-verdict.sh carries the same five and refuses a run whose
# deriver.log names any other set, so a drift between the two copies refuses rather than scores.
SUBJECTS="enforcement-map-sites enforcement-map-sites-b enforcement-map-sites-c validator-arm-selection validator-arm-selection-b"

refuse() { echo "readset-stage1-run: REFUSED: $*" >&2; exit 2; }

# THE ROOT IS FOUND BY WALKING UP FROM THIS SCRIPT FOR `.git`, never by counting `..` hops. A `.git`
# FILE marks a linked worktree, which the deriver refuses too (it copies the checkout's `.git`).
resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || refuse "cannot resolve the script directory"
ROOT="$(resolve_root "$SCRIPT_DIR")" || refuse "no .git above $SCRIPT_DIR"
[ -d "$ROOT/.git" ] || refuse "$ROOT is a LINKED worktree (its .git is a file); run from the main checkout"
DERIVER="$ROOT/core/scripts/derive-fixture-readsets.sh"
MAP="$ROOT/.ai-dlc-fixture-readsets.tsv"
[ -f "$DERIVER" ] || refuse "no deriver at $DERIVER"
[ -f "$MAP" ] || refuse "no map at $MAP -- there is nothing to snapshot, so nothing could be restored"

[ $# -eq 1 ] && [ -n "$1" ] || refuse "usage: bash $0 <RUN_DIR>"

# A DIRTY CHECKOUT IS REFUSED: the deriver copies the working tree, so the trace would carry the
# uncommitted change and print its `uncommitted path(s)` note, which the verdict refuses anyway.
PORC="$(git -C "$ROOT" status --porcelain 2>/dev/null)" || refuse "git status failed in $ROOT"
[ -z "$PORC" ] || refuse "$ROOT has uncommitted changes; a stage-1 run traces a clean commit"
HEAD_SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)" || refuse "cannot read HEAD in $ROOT"

if [ -n "${AI_DLC_READSET_STAGE1_LEDGER:-}" ]; then
  LEDGER="$AI_DLC_READSET_STAGE1_LEDGER"
else
  CDIR="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)" || refuse "cannot resolve the git common dir"
  case "$CDIR" in /*) ;; *) CDIR="$ROOT/$CDIR" ;; esac
  CDIR="$(cd "$CDIR" && pwd -P)" || refuse "cannot resolve the git common dir"
  LEDGER="$CDIR/ai-dlc-readset-stage1.ledger"
fi

# RUN_DIR MUST NOT EXIST, and `mkdir` without -p is the atomic test. It must also lie OUTSIDE the
# checkout: the deriver copies untracked files, so a RUN_DIR inside the tree would be copied into
# its own trace and would dirty the checkout after the clean check above passed.
PARENT="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || refuse "the parent of $1 does not exist"
case "$PARENT/" in
  "$ROOT"/*) refuse "$1 is inside the checkout $ROOT; put RUN_DIR outside it" ;;
esac
mkdir "$1" 2>/dev/null || refuse "$1 already exists; RUN_DIR must be new"
RUN_DIR="$(cd "$1" && pwd -P)" || refuse "cannot resolve $1"

SNAP="$RUN_DIR/map.before"
cp -p "$MAP" "$SNAP" && cmp -s "$MAP" "$SNAP" || refuse "cannot snapshot $MAP"

DPID=""; SPID_FILE="$RUN_DIR/sampler.pid"; START=""; RC="killed"; RECORDED=0; FINAL=0

sample() { printf '%s\t%s\n' "$(date +%s)" "$(sysctl -n vm.loadavg | awk '{ print $2 }')" >> "$RUN_DIR/load.tsv"; }

stop_sampler() {
  local sp
  [ -f "$SPID_FILE" ] || return 0
  sp="$(cat "$SPID_FILE")"
  case "$sp" in ''|*[!0-9]*) return 0 ;; esac
  kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
  rm -f "$SPID_FILE"
}

# THE RESTORE RUNS FROM THE TRAP, so a killed wrapper restores the map too. The deriver writes the
# map LAST, so it is killed and reaped BEFORE the copy-back: restoring while it still runs would be
# undone by its own write. Its `log stream` children are its own to reap; only its pid is named.
finish() {
  [ "$FINAL" -eq 0 ] || return 0
  FINAL=1
  trap '' INT TERM
  if [ -n "$DPID" ]; then kill "$DPID" 2>/dev/null; wait "$DPID" 2>/dev/null; fi
  stop_sampler
  if [ -n "$START" ] && [ "$RECORDED" -eq 0 ]; then
    [ -f "$RUN_DIR/rc" ] || printf '%s\n' "$RC" > "$RUN_DIR/rc"
    printf '%s\t%s\t%s\t%s\t%s\n' "$RUN_DIR" "$RC" "$START" "$(date +%s)" "$HEAD_SHA" >> "$LEDGER" \
      || echo "readset-stage1-run: could not append to the ledger $LEDGER" >&2
    RECORDED=1
  fi
  cp -p "$SNAP" "$MAP" 2>/dev/null
  if cmp -s "$SNAP" "$MAP"; then
    echo "readset-stage1-run: map restored byte-identically ($MAP)"
  else
    echo "readset-stage1-run: FAILED to restore $MAP from $SNAP -- the checkout is dirty and the next run will refuse" >&2
    exit 3
  fi
}
trap 'finish' EXIT
trap 'finish; exit 130' INT
trap 'finish; exit 143' TERM

# THE SAMPLER is stopped by the pid it wrote, never by a process-table grep. Its sleep is a child
# it waits on, so a TERM interrupts the wait and the sleep is reaped with it.
(
  sp=""
  trap '[ -n "$sp" ] && kill "$sp" 2>/dev/null; exit 0' TERM
  while :; do
    sleep 15 & sp=$!
    wait "$sp"; sp=""
    sample
  done
) &
echo "$!" > "$SPID_FILE"
sample

START="$(date +%s)"
(
  cd "$ROOT" || exit 2
  AI_DLC_READSET_TRACE_ROOT="$RUN_DIR/root" exec bash "$DERIVER" --list "$SUBJECTS" --tracer sandbox
) > "$RUN_DIR/deriver.log" 2>&1 < /dev/null &
DPID=$!
wait "$DPID"
RC=$?
DPID=""
printf '%s\n' "$RC" > "$RUN_DIR/rc"
END="$(date +%s)"
sample
stop_sampler
printf '%s\t%s\t%s\t%s\t%s\n' "$RUN_DIR" "$RC" "$START" "$END" "$HEAD_SHA" >> "$LEDGER" \
  || echo "readset-stage1-run: could not append to the ledger $LEDGER" >&2
RECORDED=1
echo "readset-stage1-run: deriver exited $RC; recorded $RUN_DIR in $LEDGER"
finish
exit "$RC"
