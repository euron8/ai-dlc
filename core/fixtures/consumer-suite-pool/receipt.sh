#!/usr/bin/env bash
# consumer-suite-pool/receipt.sh [<hook>] -- the BL-606 backlog receipt: the pool worker REFUSES a unit
# that makes no progress, and kills its whole tree.
#
# Drives the hook's OWN extracted worker body (the `xargs ... bash -c` string, with POOL_WALK) over one
# stub fixture that hangs with a grandchild `sleep`, at POOL_STALL=3. Exit 0 when the unit's verdict is
# REFUSED and every pid the stub recorded is gone; 1 otherwise; 9 when the body cannot be extracted (the
# receipt cannot measure its subject). Behaviour only: no name is grepped, so a byte signature summed
# through `stat -f %z` passes exactly as one summed from `find -ls` does.
#
# THE OUTER BOUND IS A HARNESS NET, NOT A VERDICT. A body with no bound would hang this receipt, and the
# rotator EXECUTES receipts, so after 60 one-second polls the receipt kills every pid the stub recorded,
# which lets the worker reap its own watcher and return; if it still has not after 10 more polls, the
# receipt kills the group of the xargs it started (by its recorded pid) and exits 1. Either way the
# bound-removed regression reads as "still live", never as a hang.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${1:-}"
if [ -z "$HOOK" ]; then
  for c in "$HERE/../../git-hooks/pre-push" "$HERE/../../../.githooks/pre-push"; do
    [ -f "$c" ] && { HOOK="$c"; break; }
  done
fi
[ -n "$HOOK" ] && [ -f "$HOOK" ] || { echo "receipt: no pre-push hook found" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/csp-receipt.XXXXXX")" || exit 9
awk '/xargs -P "\$FIXTURE_JOBS" -I\{\} bash -c /{f=1;next} /^  . _ \{\} < "\$out\/.order"$/{f=0} f' "$HOOK" > "$R/body.sh"
awk '/^POOL_WALK=/{f=1} f{print} f && /^}.$/{exit}' "$HOOK" > "$R/walk.sh"
[ -s "$R/body.sh" ] && [ -s "$R/walk.sh" ] || { echo "receipt: the worker body or POOL_WALK did not extract from $HOOK" >&2; rm -rf "$R"; exit 9; }
POOL_WALK=""; . "$R/walk.sh"
[ -n "$POOL_WALK" ] || { echo "receipt: POOL_WALK is empty" >&2; rm -rf "$R"; exit 9; }
mkdir -p "$R/t/core/fixtures/h" "$R/out/.log" "$R/out/.dur" "$R/out/.pr"
cat > "$R/t/core/fixtures/h/run.sh" <<EOF
echo \$\$ >> "$R/pids"
bash -c 'echo \$\$ >> "\$1"; sleep 100000 & echo \$! >> "\$1"; wait \$!; :' _ "$R/pids"
EOF
printf 'core/fixtures/h/\n' > "$R/list"
kill_recorded() { # kill every pid the stub recorded; prints how many were alive
  local p k=0
  [ -s "$R/pids" ] || { echo 0; return; }
  while read -r p; do
    case "$p" in ''|*[!0-9]*) continue ;; esac
    if kill -0 "$p" 2>/dev/null; then k=$((k + 1)); kill -KILL "$p" 2>/dev/null; fi
  done < "$R/pids"
  echo "$k"
}
set -m
( cd "$R/t" && AI_DLC_FX_OUT="$R/out" AI_DLC_FX_TRACE="" AI_DLC_FX_TRACE_LIST="" AI_DLC_FX_DV="" \
    POOL_STALL=3 POOL_WALK="$POOL_WALK" xargs -P 1 -I{} bash -c "$(cat "$R/body.sh")" _ {} < "$R/list" ) >/dev/null 2>&1 &
X=$!
set +m
rc=0; n=0
while kill -0 "$X" 2>/dev/null && [ "$n" -lt 60 ]; do n=$((n + 1)); sleep 1; done
if kill -0 "$X" 2>/dev/null; then
  rc=1; kill_recorded >/dev/null
  n=0; while kill -0 "$X" 2>/dev/null && [ "$n" -lt 10 ]; do n=$((n + 1)); sleep 1; done
  kill -0 "$X" 2>/dev/null && kill -KILL -- "-$X" 2>/dev/null
fi
wait "$X" 2>/dev/null
[ "$(cat "$R/out/h" 2>/dev/null)" = REFUSED ] || rc=1
[ -s "$R/pids" ] || rc=1
[ "$(kill_recorded)" = 0 ] || rc=1
rm -rf "$R"
exit "$rc"
