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

# A1 and A2 -- THE WINDOW VALUE ITSELF, checked first because they cost milliseconds and the pool
# arm below costs a minute. The pool arm drives the worker at POOL_STALL=3, so it says nothing about
# the DEFAULT, and the fallbacks reuse that default: a filled 0 refuses every unit on its first poll,
# a filled 1e3 is not an integer and disables refusal, and a backlog value that differs from the
# hooks' records a measurement nothing shipped.
#   A1  each pre-push hook carries the `# D9-WINDOW` marker on exactly ONE line, that line is
#       `POOL_STALL_DEFAULT=<N>` with N a plain decimal of 1-5 digits and no leading zero, and the
#       two hooks carry the same N.
#   A2  the BL-606 entry (its `## BL-606 ` heading to the next `## `), held by exactly one of
#       docs/backlog.md and docs/backlog.archive.md, carries exactly one
#       `Window: POOL_STALL_DEFAULT=<N> polls` line, and that N is the hooks' N. The archive counts
#       because rotation moves the entry there; backlog-rotate.sh runs this receipt BEFORE the move,
#       so at rotation time the entry is still in docs/backlog.md.
# An unfilled `<D9-WINDOW>` token fails A2, and must: an unfilled release does not pass.
# Exit 1 on a failed assertion; exit 9 when an input is ABSENT (no repository root, either hook, or
# docs/), which is every consumer tree -- this fixture ships, and they carry none of the three. With
# docs/ present and the entry in neither file the entry was deleted, which is a FAIL, not an absence.
d9_root() { # walk up from $1 for a repository marker; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
D9_ROOT="$(d9_root "$HERE")" || D9_ROOT=""
[ -n "$D9_ROOT" ] || { echo "receipt: cannot measure: no repository root above $HERE" >&2; exit 9; }
D9_MISSING=""
for f in .githooks/pre-push core/git-hooks/pre-push; do
  [ -f "$D9_ROOT/$f" ] || D9_MISSING="$D9_MISSING $f"
done
[ -d "$D9_ROOT/docs" ] || D9_MISSING="$D9_MISSING docs/"
[ -z "$D9_MISSING" ] || { echo "receipt: cannot measure: absent input(s):$D9_MISSING under $D9_ROOT" >&2; exit 9; }
D9_VAL=""; D9_FROM=""
for f in .githooks/pre-push core/git-hooks/pre-push; do
  n="$(grep -c '# D9-WINDOW' "$D9_ROOT/$f")" || n=0
  [ "$n" = 1 ] || { echo "receipt: A1 FAIL: $f carries the D9-WINDOW marker on $n line(s), want exactly 1" >&2; exit 1; }
  line="$(grep '# D9-WINDOW' "$D9_ROOT/$f")"
  v="$(sed -n 's/^POOL_STALL_DEFAULT=\([1-9][0-9]\{0,4\}\)[[:blank:]][[:blank:]]*# D9-WINDOW$/\1/p' <<<"$line")"
  [ -n "$v" ] || { echo "receipt: A1 FAIL: $f D9-WINDOW line is '$line', want POOL_STALL_DEFAULT=<1-5 digits, no leading zero, >= 1>" >&2; exit 1; }
  if [ -n "$D9_VAL" ] && [ "$v" != "$D9_VAL" ]; then
    echo "receipt: A1 FAIL: the hooks disagree, $D9_FROM POOL_STALL_DEFAULT=$D9_VAL against $f POOL_STALL_DEFAULT=$v" >&2; exit 1
  fi
  D9_VAL="$v"; D9_FROM="$f"
done
D9_HOLD=""; D9_HN=0; D9_SEC=""
for f in docs/backlog.md docs/backlog.archive.md; do
  [ -f "$D9_ROOT/$f" ] || continue
  h="$(grep -c '^## BL-606 ' "$D9_ROOT/$f")" || h=0
  [ "$h" = 0 ] && continue
  D9_HN=$((D9_HN + h)); D9_HOLD="$D9_HOLD $f($h)"
  D9_SEC="$(awk '/^## BL-606 /{f=1; print; next} f && /^## /{f=0} f' "$D9_ROOT/$f")"
done
[ "$D9_HN" = 1 ] || { echo "receipt: A2 FAIL: want exactly one '## BL-606 ' heading across docs/backlog.md and docs/backlog.archive.md, found $D9_HN:${D9_HOLD:- none}" >&2; exit 1; }
n="$(grep -c '^Window: POOL_STALL_DEFAULT=' <<<"$D9_SEC")" || n=0
[ "$n" = 1 ] || { echo "receipt: A2 FAIL: the BL-606 entry in$D9_HOLD carries $n 'Window: POOL_STALL_DEFAULT=' line(s), want exactly 1" >&2; exit 1; }
line="$(grep '^Window: POOL_STALL_DEFAULT=' <<<"$D9_SEC")"
v="$(sed -n 's/^Window: POOL_STALL_DEFAULT=\([1-9][0-9]\{0,4\}\) polls.*$/\1/p' <<<"$line")"
[ "$v" = "$D9_VAL" ] || { echo "receipt: A2 FAIL: the BL-606 entry in$D9_HOLD records POOL_STALL_DEFAULT='${v:-$(sed -n 's/^Window: POOL_STALL_DEFAULT=\([^ ]*\).*$/\1/p' <<<"$line")}', the hooks carry $D9_VAL" >&2; exit 1; }
# --- end of A1/A2 ---

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
