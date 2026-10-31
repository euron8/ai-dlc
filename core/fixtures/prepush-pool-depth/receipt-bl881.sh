#!/usr/bin/env bash
# core/fixtures/prepush-pool-depth/receipt-bl881.sh [<hook>] -- the BL-881 backlog receipt: a TERM to the pre-push
# hook tears down its fixture pool.
#
# Drives the hook's OWN FIXTURE_POOL block (extracted between its BEGIN/END markers, the way
# core/fixtures/prepush-pool-depth/run.sh does) as `run_fixtures` over a seeded world of four stub units
# at width 2. Each stub records "<pid> <pool root>" and then holds on a barrier FILE this receipt writes,
# so exactly two units are in flight and two are queued when the signal lands. The receipt then TERMs
# the one process it started (the shell running run_fixtures) and asserts:
#   A1  the parent is gone within BOUND seconds, with exit status 143
#   A2  every stub pid it recorded is dead (not live, not merely exiting or a zombie) within BOUND
#       seconds of the TERM
#   A3  no queued stub ever started (2 recorded; the `.stop` record makes xargs stop dispatching)
#   A4  the pool root the stubs recorded is removed
# Exit 0 when all four hold; 1 when any fails (each failing assertion prints a FAIL line naming it);
# 9 when the receipt cannot measure its subject (no hook, an empty block, no fixture root, or the
# pool never started two stubs).
#
# Signals go ONLY to the pid this receipt started; the stubs end on the barrier release, never by a
# kill. Behaviour only: no hook line is grepped, so any spelling that tears the pool down passes.
set -uo pipefail
r881_seam() { # walk up from $1 for the git-env seam; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/fixtures/lib/preamble.sh" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(r881_seam "$(cd "$(dirname "$0")" && pwd)")" || ROOT=""
[ -n "$ROOT" ] || { echo "REFUSED: no core/fixtures/lib/preamble.sh above $0" >&2; exit 9; }
. "$ROOT/core/fixtures/lib/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset PREPUSH_POOL_DEPTH
HOOK="${1:-$ROOT/.githooks/pre-push}"
[ -f "$HOOK" ] || { echo "REFUSED: no hook at $HOOK" >&2; exit 9; }
BOUND=60   # a hang guard: a ceiling that ends a wait is "cannot measure" (exit 9), never a verdict
T="$(mktemp -d "${TMPDIR:-/tmp}/bl881.XXXXXX")" || exit 9
[ -d "$T" ] || exit 9
trap ': > "$T/s/release" 2>/dev/null; rm -rf "$T"' EXIT
sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK" > "$T/block.sh"
[ -s "$T/block.sh" ] || { echo "REFUSED: empty FIXTURE_POOL block in $HOOK" >&2; exit 9; }
FXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$T/block.sh" | sort -u)"
[ "$(printf '%s\n' "$FXR" | grep -c .)" -eq 1 ] || { echo "REFUSED: fixture root read as '$FXR', need exactly one" >&2; exit 9; }
mkdir -p "$T/s" "$T/store" || exit 9
for i in 1 2 3 4; do
  mkdir -p "$T/w/$FXR/q$i" || exit 9
  cat > "$T/w/$FXR/q$i/run.sh" <<'FX'
#!/usr/bin/env bash
printf '%s %s\n' "$$" "${TMPDIR%/*}" > "$R881_DIR/s.$$"
s=$SECONDS
while [ ! -e "$R881_DIR/release" ] && [ -d "$R881_DIR" ] && [ $((SECONDS - s)) -lt 300 ]; do sleep 0.1; done
exit 0
FX
done
( cd "$T/w" && git init -q . && git add -A && git -c user.email=r@r -c user.name=r commit -qm seed ) > /dev/null 2>&1
[ -d "$T/w/.git" ] || { echo "REFUSED: the stub world is not a repository" >&2; exit 9; }

nstubs() { ls "$T/s" | grep -c '^s\.'; }
stubs() { cat "$T/s"/s.* 2>/dev/null | cut -d' ' -f1; }
alive() { # how many of the recorded stub pids are live and neither exiting nor a zombie
  local p n=0 st
  for p in $(stubs); do
    kill -0 "$p" 2>/dev/null || continue
    st="$(ps -o stat= -p "$p" 2>/dev/null)"
    case "$st" in Z*|E*|'') ;; *) n=$((n + 1)) ;; esac
  done
  printf '%s' "$n"
}

set -m
( cd "$T/w" && export AI_DLC_FIXTURE_JOBS=2 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 \
    AI_DLC_VERDICT_STORE="$T/store" R881_DIR="$T/s" \
  && exec bash -c '. "$1" > /dev/null 2>&1; run_fixtures > "$2" 2>&1' _ "$T/block.sh" "$T/out" ) > /dev/null 2>&1 &
P=$!
set +m
s=$SECONDS
while [ "$(nstubs)" -lt 2 ] && [ $((SECONDS - s)) -lt "$BOUND" ]; do sleep 0.1; done
if [ "$(nstubs)" -lt 2 ]; then
  : > "$T/s/release"; wait "$P"
  echo "REFUSED: the pool started $(nstubs) stub(s) in ${BOUND}s, want 2" >&2; exit 9
fi
PROOT="$(sed -n '1s/^[0-9]* //p' "$T/s/$(ls "$T/s" | grep '^s\.' | sed -n 1p)")"

kill -TERM "$P"
s=$SECONDS
while kill -0 "$P" 2>/dev/null && [ $((SECONDS - s)) -lt "$BOUND" ]; do sleep 0.1; done
pgone=1; kill -0 "$P" 2>/dev/null && pgone=0
while [ "$(alive)" != 0 ] && [ $((SECONDS - s)) -lt "$BOUND" ]; do sleep 0.1; done
n_alive="$(alive)"; n_started="$(nstubs)"
# The parent's exit is the event: once it is gone every stub is reaped or it never will be, so stubs alive
# after it is A2's verdict. The ceiling ending the wait for the parent itself is a hang guard, not a verdict.
if [ "$pgone" = 0 ]; then
  : > "$T/s/release"; wait "$P"
  echo "REFUSED: the ${BOUND}s ceiling ended the wait for the parent to exit; a ceiling is a hang guard, so this cannot be measured" >&2; exit 9
fi
: > "$T/s/release"
wait "$P"; st=$?
rc=0
if [ "$pgone" = 1 ] && [ "$st" = 143 ]; then :; else
  rc=1; echo "FAIL: A1 parent gone within ${BOUND}s=$pgone, exit status $st, want gone and 143"
fi
[ "$n_alive" = 0 ] || { rc=1; echo "FAIL: A2 $n_alive recorded stub pid(s) still alive ${BOUND}s after the TERM, want 0"; }
[ "$n_started" = 2 ] || { rc=1; echo "FAIL: A3 $n_started stub(s) started, want 2 (a queued unit was dispatched after the TERM)"; }
[ -n "$PROOT" ] && [ ! -d "$PROOT" ] || { rc=1; echo "FAIL: A4 pool root '${PROOT:-unrecorded}' survives the TERM"; }
[ "$rc" = 0 ] && echo "PASS: TERM -> parent exit 143, 0 of 2 recorded stubs alive, no queued unit started, pool root removed"
exit "$rc"
