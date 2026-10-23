#!/usr/bin/env bash
# slot-world.sh -- drives the read-set deriver's TRACE-WINDOW SLOT (BL-584) in a stub-stream world.
#
# Usage: slot-world.sh <deriver> <hook> [scenario ...]
#   <deriver>  a copy of core/scripts/derive-fixture-readsets.sh (the shipped one, or a mutant)
#   <hook>     the pre-push hook whose READSET_LOCK span the world's runner carries
#   scenario   any of: order nested stalemark foreign stale beat plain (default: all)
# Prints one `PASS <scenario>` or `FAIL <scenario>: <why>` line per scenario.
# Exit:  0 = every scenario passed, 1 = one did not, 9 = the world could not be built (not a verdict).
#
# ONE SOURCE FOR TWO READERS: core/fixtures/readset-skip's `slot` unit runs it against the shipped
# deriver and against one mutant per property, and BL-584's `verify: sh` receipt runs it against the
# shipped deriver. Both therefore DRIVE the deriver; neither greps its text.
#
# NO REAL `log stream`, AND NO CLOCK. The deriver's one LOG_BIN line is pointed at a stub that tails a
# feed file, and a stub sandbox-exec appends the report lines a profile would. Every property is read
# off an ORDERING RECORD the fixtures write (`a-in`, `b-waited`, `a-out`, `b-in`, `b-out`) or off a line
# the deriver must PRINT; the only waits are bounded polls that exist so a regressed deriver cannot hang
# the caller, and their bound is never the thing measured.
#
# THE WORLD: one repo whose runner carries the hook's READSET_LOCK span and the FXROOT line, with two
# fixtures. `fa`, traced by deriver A, records `a-in`, then (in the scenarios that need a second
# deriver) starts deriver B on `fb` with a chosen READSET_SLOT_HOLDER, waits until B either prints
# `slot: waiting` (recorded as `b-waited`) or finishes `fb`, and records `a-out`. `fb` records `b-in`
# and `b-out`. So `a-in b-waited a-out b-in b-out` is two windows in sequence and `a-in b-in b-out a-out`
# is B's window inside A's.
#   order      B a sibling (no marker): must wait                -> a-in b-waited a-out b-in b-out
#   nested     B inherits A's live marker: must NOT wait         -> a-in b-in b-out a-out, and B says nested
#   stalemark  B's marker names a DEAD pid on this slot: waits   -> a-in b-waited a-out b-in b-out
#   foreign    B's marker names a LIVE pid the slot's pid file does not: waits -> the same
#   stale      the slot is pre-held by a dead pid: A breaks it, says so, and never says waiting
#   beat       the slot is pre-held by a live pid: a waiting A prints a heartbeat (interval cut to 1 poll)
#   plain      the slot is pre-held by a live pid: a plain `--list --tracer sandbox` run does not wait
set -uo pipefail

[ $# -ge 2 ] || { echo "usage: slot-world.sh <deriver> <hook> [scenario ...]" >&2; exit 9; }
DV_IN="$1"; HK_IN="$2"; shift 2
[ -f "$DV_IN" ] && [ -f "$HK_IN" ] || { echo "slot-world: cannot read $DV_IN or $HK_IN" >&2; exit 9; }
DV_IN="$(cd "$(dirname "$DV_IN")" && pwd -P)/$(basename "$DV_IN")"
HK_IN="$(cd "$(dirname "$HK_IN")" && pwd -P)/$(basename "$HK_IN")"
SCEN="$*"; [ -n "$SCEN" ] || SCEN="order nested stalemark foreign stale beat plain"

W="$(mktemp -d "${TMPDIR:-/tmp}/slot-world.XXXXXX")" || exit 9
W="$(cd "$W" && pwd -P)"
LIVE=""
cleanup() { [ -n "$LIVE" ] && kill "$LIVE" 2>/dev/null; [ -n "${SW_KEEP:-}" ] || rm -rf "$W"; }
trap cleanup EXIT

# THE STUBS. sandbox-exec strips `-D FXTAG=<tag>` and `-f <profile>`, appends one tagged report line per
# absolute-path argument (the sentinel and end-marker reads), and execs the command.
ST="$W/stub"; mkdir -p "$ST" "$W/beatbin" || exit 9
cat > "$ST/sandbox-exec" <<'STUB'
#!/bin/bash
tag=""
[ "${1:-}" = -D ] && { tag="${2#FXTAG=}"; shift 2; }
[ "${1:-}" = -f ] && shift 2
for a in "$@"; do case "$a" in /*) printf 'x Sandbox: cat(1) allow file-read-data %s\nFXTAG=%s;\n' "$a" "$tag" >> "$STUB_FEED" ;; esac; done
# NOT `exec`: the deriver's profile probe runs `true`, and under hermetic-run's PATH there is no `true`
# binary for exec to find -- run as a command, bash takes its builtin.
"$@"
STUB
cat > "$ST/logstream" <<'STUB'
#!/bin/bash
exec tail -n 0 -f "$STUB_FEED"
STUB
# The beat scenario's sleep counts its calls, so the world can wait for N wait-loop polls without a clock.
cat > "$W/beatbin/sleep" <<'STUB'
#!/bin/bash
echo x >> "$SW_SLEEPS"
exec /bin/sleep "$@"
STUB
chmod +x "$ST/sandbox-exec" "$ST/logstream" "$W/beatbin/sleep" || exit 9

R="$W/repo"
mkdir -p "$R/.githooks" "$R/core/scripts" "$R/core/fixtures/fa" "$R/core/fixtures/fb" || exit 9
{ printf '#!/bin/bash\nFXROOT="core/fixtures/"\nfor d in "$FXROOT"*/; do :; done\n'
  sed -n '/^# READSET_LOCK_BEGIN$/,/^# READSET_LOCK_END$/p' "$HK_IN"; } > "$R/.githooks/pre-push"
grep -q '^readset_lock_stale() ' "$R/.githooks/pre-push" \
  || { echo "slot-world: $HK_IN carries no READSET_LOCK span with readset_lock_stale -- nothing to source" >&2; exit 9; }
sed "s|^LOG_BIN=/usr/bin/log\$|LOG_BIN=\"$ST/logstream\"|" "$DV_IN" > "$R/core/scripts/derive-fixture-readsets.sh"
cmp -s "$DV_IN" "$R/core/scripts/derive-fixture-readsets.sh" \
  && { echo "slot-world: the LOG_BIN line is gone from $DV_IN, so the stream cannot be stubbed" >&2; exit 9; }
sed 's/^RS_SLOT_BEAT=100$/RS_SLOT_BEAT=1/' "$R/core/scripts/derive-fixture-readsets.sh" > "$W/deriver.beat.sh"
cmp -s "$R/core/scripts/derive-fixture-readsets.sh" "$W/deriver.beat.sh" \
  && { echo "slot-world: no 'RS_SLOT_BEAT=100' line in $DV_IN, so the heartbeat interval cannot be cut" >&2; exit 9; }
cat > "$R/core/fixtures/fa/run.sh" <<'FX'
#!/bin/bash
O="$SW_ORDER"; echo a-in >> "$O"
if [ -n "${SW_B_MODE:-}" ]; then
  case "$SW_B_MODE" in
    sibling)   m="" ;;
    nested)    m="${READSET_SLOT_HOLDER:-}" ;;
    stalemark) m="$SW_DEADPID:$AI_DLC_READSET_SLOT" ;;
    foreign)   m="$SW_LIVEPID:$AI_DLC_READSET_SLOT" ;;
  esac
  ( cd "$SW_R" && exec env READSET_SLOT_HOLDER="$m" STUB_FEED="$SW_FEEDB" AI_DLC_READSET_TRACE_ROOT="$SW_TRB" \
      bash core/scripts/derive-fixture-readsets.sh --list fb --tracer sandbox --in-pool "$SW_IPB" ) > "$SW_BOUT" 2>&1 </dev/null &
  echo "$!" > "$SW_BPID"
  i=0
  while [ "$i" -lt 3000 ]; do
    grep -q 'slot: waiting' "$SW_BOUT" 2>/dev/null && { echo b-waited >> "$O"; break; }
    grep -qx b-out "$O" && break
    /bin/sleep 0.1; i=$((i + 1))
  done
fi
echo a-out >> "$O"
FX
printf '#!/bin/bash\necho b-in >> "$SW_ORDER"\necho b-out >> "$SW_ORDER"\n' > "$R/core/fixtures/fb/run.sh"
( cd "$R" && git init -q . && git add -A && git -c user.email=s@w -c user.name=s commit -qm slot-world ) >/dev/null 2>&1 || exit 9

/bin/sleep 600 </dev/null >/dev/null 2>&1 &
LIVE=$!
( : ) & DEAD=$!; wait "$DEAD"
kill -0 "$DEAD" 2>/dev/null && { echo "slot-world: the dead-pid control $DEAD is alive" >&2; exit 9; }

# wait_for <pid> <file> <ERE> -- poll until <file> matches or <pid> exits; bounded, never measured.
wait_for() {
  local i=0
  while [ "$i" -lt 3000 ]; do
    grep -Eq "$3" "$2" 2>/dev/null && return 0
    kill -0 "$1" 2>/dev/null || { grep -Eq "$3" "$2" 2>/dev/null; return; }
    /bin/sleep 0.1; i=$((i + 1))
  done
  return 1
}
# reap <pid> -- wait a bounded while for a deriver to finish on its own, then kill it by its recorded pid.
reap() {
  local i=0
  while kill -0 "$1" 2>/dev/null && [ "$i" -lt 600 ]; do /bin/sleep 0.1; i=$((i + 1)); done
  kill -0 "$1" 2>/dev/null && kill -KILL "$1" 2>/dev/null
  wait "$1" 2>/dev/null
  return 0
}

rc=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; rc=1; }

# run_a <scenario> <dir> <deriver> <B mode> <mode args...> -- starts deriver A in the background; sets APID.
run_a() {
  local s="$1" d="$2" dv="$3" bm="$4"; shift 4
  mkdir -p "$d" || exit 9
  : > "$d/order"; : > "$d/feedA"; : > "$d/feedB"; : > "$d/bout"; : > "$d/sleeps"
  cp "$dv" "$R/core/scripts/derive-fixture-readsets.sh" || exit 9
  local P="$ST:$PATH"; [ "$s" = beat ] && P="$W/beatbin:$P"
  ( cd "$R" && exec env -u READSET_SLOT_HOLDER PATH="$P" AI_DLC_READSET_SLOT="$d/slot" STUB_FEED="$d/feedA" \
      AI_DLC_READSET_TRACE_ROOT="$d/trA" SW_ORDER="$d/order" SW_B_MODE="$bm" SW_R="$R" SW_FEEDB="$d/feedB" \
      SW_TRB="$d/trB" SW_IPB="$d/ipB" SW_BOUT="$d/bout" SW_BPID="$d/bpid" SW_DEADPID="$DEAD" SW_LIVEPID="$LIVE" \
      SW_SLEEPS="$d/sleeps" bash core/scripts/derive-fixture-readsets.sh "$@" ) > "$d/aout" 2>&1 </dev/null &
  APID=$!
}
order_of() { tr '\n' ' ' < "$1/order" | sed 's/ $//'; }
pair() { # <scenario> <B mode> <expected order>
  local s="$1" d="$W/$1" got bp
  run_a "$s" "$d" "$W/deriver.in.sh" "$2" --list fa --tracer sandbox --in-pool "$d/ipA"
  wait_for "$APID" "$d/aout" 'slot: (waiting|broke)|copying the tree' >/dev/null
  reap "$APID"
  bp="$(cat "$d/bpid" 2>/dev/null)"
  [ -n "$bp" ] && reap "$bp"
  got="$(order_of "$d")"
  if [ "$got" != "$3" ]; then fail "$s" "order '$got', expected '$3' -- A: $(grep -m1 'ERROR' "$d/aout" | cut -c1-300) B: $(grep -m1 'slot:\|ERROR' "$d/bout" | cut -c1-100)"; return; fi
  case "$s" in
    nested) grep -q 'slot: nested inside holder' "$d/bout" || { fail "$s" "deriver B ran inside A's window without saying it was nested"; return; } ;;
  esac
  pass "$s"
}
cp "$R/core/scripts/derive-fixture-readsets.sh" "$W/deriver.in.sh" || exit 9

for s in $SCEN; do
  d="$W/$s"
  case "$s" in
    order)     pair order sibling 'a-in b-waited a-out b-in b-out' ;;
    nested)    pair nested nested 'a-in b-in b-out a-out' ;;
    stalemark) pair stalemark stalemark 'a-in b-waited a-out b-in b-out' ;;
    foreign)   pair foreign foreign 'a-in b-waited a-out b-in b-out' ;;
    stale)
      mkdir -p "$d/slot" && printf '%s %s\n' "$DEAD" "$(date +%s)" > "$d/slot/pid" || exit 9
      run_a stale "$d" "$W/deriver.in.sh" "" --list fa --tracer sandbox --in-pool "$d/ipA"
      wait_for "$APID" "$d/aout" 'slot: (waiting|broke)' >/dev/null
      grep -q 'slot: waiting' "$d/aout" && kill -KILL "$APID" 2>/dev/null
      reap "$APID"
      if grep -q "slot: broke a stale slot .* (holder pid $DEAD)" "$d/aout" && ! grep -q 'slot: waiting' "$d/aout" \
         && [ "$(order_of "$d")" = 'a-in a-out' ]; then pass stale
      else fail stale "expected 'broke a stale slot' naming pid $DEAD, no wait, and fa run: order '$(order_of "$d")', $(grep -m1 'slot:' "$d/aout" | cut -c1-100)"; fi ;;
    beat)
      mkdir -p "$d/slot" && printf '%s %s\n' "$LIVE" "$(date +%s)" > "$d/slot/pid" || exit 9
      run_a beat "$d" "$W/deriver.beat.sh" "" --list fa --tracer sandbox --in-pool "$d/ipA"
      if wait_for "$APID" "$d/aout" 'slot: waiting'; then
        n0="$(grep -c . "$d/sleeps")" || n0=0
        i=0; while [ "$i" -lt 3000 ] && kill -0 "$APID" 2>/dev/null; do
          n="$(grep -c . "$d/sleeps")" || n=0
          [ "$n" -ge $((n0 + 3)) ] && break
          /bin/sleep 0.1; i=$((i + 1))
        done
      fi
      kill -KILL "$APID" 2>/dev/null; reap "$APID"
      if grep -q 'slot: waiting' "$d/aout" && grep -q 'slot: heartbeat, still waiting' "$d/aout" && [ ! -s "$d/order" ]; then pass beat
      else fail beat "a waiter behind live pid $LIVE printed no heartbeat over 3 polls (or never waited, or ran fa): $(grep 'slot:' "$d/aout" | head -2 | tr '\n' ' ' | cut -c1-160)"; fi ;;
    plain)
      mkdir -p "$d/slot" && printf '%s %s\n' "$LIVE" "$(date +%s)" > "$d/slot/pid" || exit 9
      run_a plain "$d" "$W/deriver.in.sh" "" --list fa --tracer sandbox
      wait_for "$APID" "$d/aout" 'slot: waiting|^  fa ' >/dev/null
      grep -q 'slot: waiting' "$d/aout" && kill -KILL "$APID" 2>/dev/null
      reap "$APID"
      if ! grep -q 'slot:' "$d/aout" && [ "$(order_of "$d")" = 'a-in a-out' ] && [ -d "$d/slot" ]; then pass plain
      else fail plain "a plain --list run touched the slot held by live pid $LIVE: order '$(order_of "$d")', $(grep -m1 'slot:' "$d/aout" | cut -c1-100)"; fi ;;
    *) echo "slot-world: unknown scenario '$s'" >&2; exit 9 ;;
  esac
done
exit "$rc"
