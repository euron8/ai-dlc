#!/usr/bin/env bash
# receipt-bl875.sh [slot-world] -- BL-875 item (5)'s backlog receipt. Drives the REAL slot-world `hold` world with
# SW_FORK_GATE set, so the world blocks on the statement right after deriver A's launch (where it once appended `$!`
# itself), SIGKILLs the world there, reaps every group in the record it named, and reads deriver A's group through the
# pid file A's own launch wrote, never through the record. No clock: the gate is a sentinel the world writes.
# Asserts: the gate was reached with A's group live (pre), the record holds both groups (live control and A), and A's
# group is gone after the reap.
# Exit: 0 = no group outlives the KILL, 1 = BL-875 regressed, 9 = the receipt cannot measure its subject.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SW="${1:-$here/slot-world.sh}"
root="$here"
while [ "$root" != / ] && [ ! -f "$root/core/scripts/derive-fixture-readsets.sh" ]; do root="$(dirname "$root")"; done
DV="$root/core/scripts/derive-fixture-readsets.sh"
HK=""
for c in "$root/.githooks/pre-push" "$root/core/git-hooks/pre-push"; do [ -f "$c" ] && { HK="$c"; break; }; done
[ -f "$SW" ] && [ -f "$DV" ] && [ -n "$HK" ] && [ -f "$here/run.sh" ] || exit 9
T="$(mktemp -d "${TMPDIR:-/tmp}/bl875.XXXXXX")" || exit 9
sed -n '/^# STUB_STREAM_BEGIN$/,/^# STUB_STREAM_END$/p' "$here/run.sh" > "$T/ss.sh"
grep -q '^ss_wait() ' "$T/ss.sh" || exit 9
gf="$T/groups"; : > "$gf"
( TMPDIR="$T" SW_GROUPS="$gf" SW_FORK_GATE="$T/gate" STUB_STREAM_LIB="$T/ss.sh" bash "$SW" "$DV" "$HK" hold ) > "$T/wout" 2>&1 &
swp=$!
# Bounded by the world's own exit: a world that never reaches the gate ends the wait.
while [ ! -e "$T/gate" ] && kill -0 "$swp" 2>/dev/null; do sleep 0.1; done
d="$(ls -d "$T"/slot-world.*/hold 2>/dev/null | head -1)"
ap="$(cat "$d/apid" 2>/dev/null)"
pre=0; [ -e "$T/gate" ] && grep -qx a-hold "$d/order" 2>/dev/null && [ -n "$ap" ] && kill -0 -- "-$ap" 2>/dev/null && kill -0 "$swp" 2>/dev/null && pre=1
kill -KILL "$swp" 2>/dev/null; wait "$swp" 2>/dev/null
while IFS= read -r g; do
  case "$g" in ''|0|*[!0-9]*) continue ;; esac
  kill -KILL -- "-$g" 2>/dev/null; kill -KILL "$g" 2>/dev/null
done < "$gf"
ng="$(grep -c . "$gf")" || ng=0
# A killed group empties; one nobody killed keeps its blocked `tail -f` forever. Wait until the group is empty or
# every live member is blocked with nothing pending (a member the kill never reached).
settled() {
  local p st pd n=0
  for p in $(pgrep -g "$1" 2>/dev/null); do
    kill -0 "$p" 2>/dev/null || continue
    st="$(ps -o stat= -p "$p" 2>/dev/null | tr -d ' ')"; pd="$(ps -o pending= -p "$p" 2>/dev/null | tr -d ' ')"
    case "$st" in S*|I*|T*) ;; *) return 1 ;; esac
    case "$pd" in ''|*[!0]*) return 1 ;; esac
    n=$((n + 1))
  done
  [ "$n" -gt 0 ]
}
sv=0
if [ -n "$ap" ]; then
  while kill -0 -- "-$ap" 2>/dev/null && ! settled "$ap"; do sleep 0.1; done
  kill -0 -- "-$ap" 2>/dev/null && sv=1
  kill -KILL -- "-$ap" 2>/dev/null; kill -KILL "$ap" 2>/dev/null
fi
echo "bl875: pre=$pre groups=$ng A-surviving=$sv"
[ "$pre" = 1 ] || exit 9
[ "$ng" = 2 ] && [ "$sv" = 0 ] && exit 0
exit 1
