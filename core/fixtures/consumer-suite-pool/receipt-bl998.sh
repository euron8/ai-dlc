#!/usr/bin/env bash
# receipt-bl998.sh [hook] -- the BL-998 receipt. A green fixture whose subject is absent prints `PENDING  <what>`
# rows and exits 0. The consumer pre-push hook counts those rows in the logs of the fixtures a push DISPATCHES; the
# defect is that a fixture skipped on a recorded pass is never re-read, so from its second push on the operator
# saw no PENDING line at all. This receipt DRIVES the consumer hook (never a grep of its text) over one world and
# reads what it prints.
#
# THE WORLD: a consumer-layout repository (the hook at `.githooks/pre-push`, fixtures under `tests/fixtures/`),
# committed once, holding two green fixtures. `pend` prints two PENDING rows, one indented and one at column 0
# (the two shapes the shipped emitters use). `near` is its near-miss: the word mid-line, and once with one space,
# so it prints no row. Both are pushed twice over the SAME tree, with the verdict store and the read-set trace
# pointed away from the operator's real state.
#
#   push1-dispatched  the first push RAN both: rc 0, `pend`'s ok row carries `(2 PENDING row(s) ...)` and the
#                     green clause names it. The control that the world exists and the counter works at all.
#   push2-skipped     the second push dispatched NOTHING: rc 0, `read-set keys: 0 of 2 fixture(s) run`, and no
#                     `ok    pend` row. Any re-run measured nothing about the skip path, and the receipt exits 9
#                     rather than scoring that run. (A record with no `#pending` line is no run reason: a count
#                     that did not travel shows as `count unrecorded` in push2-recorded, which then FAILs.)
#   push2-recorded    the subject. The second push prints exactly
#                     `   PENDING: 1 skipped on a recorded pass that printed a PENDING row: pend(recorded)=2`
#                     and names `near` nowhere on a PENDING line. Before the fix this push printed no PENDING
#                     line, and FAILs here on the exact line.
#
# No timing, no sleep, no retry, no load-sensitive count (BL-868): each cell is one exact line of one drive.
#
# Exit 0 when every cell PASSes, 1 when any FAILs, 9 when it cannot measure. The hook is $1, else the one this file's
# layout names, found by walking up for the nearest `core/git-hooks/pre-push` (distribution) or `.githooks/pre-push`
# (consumer), the distribution tried first at each level. Invoked by run.sh, and by `verify:` from the repository root.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${1:-}"
if [ -z "$HOOK" ]; then
  # Walk UP from this file's directory for a marker, the way ai_dlc_resolve_root() does in
  # core/scripts/validate-provenance-block.sh, never by counting `..` hops. The marker is the layout's own hook,
  # distribution first at each level (a distribution root carries .githooks/pre-push too). Not .git/.claude:
  # hermetic-run.sh's sandbox root carries neither, by design.
  d="$HERE"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/git-hooks/pre-push" ]; then HOOK="$d/core/git-hooks/pre-push"; break; fi
    if [ -f "$d/.githooks/pre-push" ]; then HOOK="$d/.githooks/pre-push"; break; fi
    d="$(dirname "$d")"
  done
fi
[ -n "$HOOK" ] && [ -f "$HOOK" ] || { echo "receipt-bl998: no pre-push hook (given: ${1:-none}; none beside $HERE in either layout)" >&2; exit 9; }
HOOK="$(cd "$(dirname "$HOOK")" && pwd -P)/${HOOK##*/}"
command -v git >/dev/null 2>&1 || { echo "receipt-bl998: git not on PATH" >&2; exit 9; }
echo "receipt-bl998: hook $HOOK"

W="$(mktemp -d "${TMPDIR:-/tmp}/rcpt998.XXXXXX")" || exit 9
W="$(cd "$W" && pwd -P)"
trap 'rm -rf "$W"' EXIT
die() { echo "receipt-bl998: $1" >&2; exit 9; }
fail=0
cell() { if [ "$2" = 0 ]; then echo "CELL $1 PASS $3"; else echo "CELL $1 FAIL $4"; fail=1; fi; }

T="$W/world"
mkdir -p "$T/.githooks" "$T/tests/fixtures/pend" "$T/tests/fixtures/near" "$W/store" || die "mkdir failed"
cp "$HOOK" "$T/.githooks/pre-push" && chmod +x "$T/.githooks/pre-push" || die "cannot copy the hook"
printf '#!/usr/bin/env bash\necho "  PENDING  r998: the subject is absent"\necho "PENDING  r998: a second absent part"\nexit 0\n' > "$T/tests/fixtures/pend/run.sh"
printf '#!/usr/bin/env bash\necho "near: not PENDING  here"\necho "PENDING (one space, a different row)"\nexit 0\n' > "$T/tests/fixtures/near/run.sh"
git -c init.defaultBranch=main init -q "$T" && git -C "$T" config user.email r@example.com \
  && git -C "$T" config user.name Receipt && git -C "$T" config commit.gpgsign false \
  && git -C "$T" add -A && git -C "$T" commit -q -m world || die "cannot build the world repository"

drive() { # drive <outfile> -> rc
  ( cd "$T" && AI_DLC_VERDICT_STORE="$W/store" AI_DLC_READSET_LIVE_TRACE=0 bash .githooks/pre-push </dev/null >"$1" 2>&1; echo $? )
}
pline() { grep -E '^   PENDING: ' "$1"; }

# ---- push 1: both fixtures dispatched -------------------------------------------------------------------
r1="$(drive "$W/p1.out")"
if [ "$r1" = 0 ] \
   && grep -qxF '   ok    pend  (2 PENDING row(s): its subject is absent, so those parts checked nothing)' "$W/p1.out" \
   && grep -qxF '   ok    near' "$W/p1.out" \
   && grep -qF ' green fixture(s) printed a PENDING row, so part of each checked nothing: pend' <<<"$(pline "$W/p1.out")"; then
  cell push1-dispatched 0 "rc 0, pend ran with 2 PENDING rows, near bare"
else
  cell push1-dispatched 1 "" "rc=$r1: $(grep -E 'ok    |PENDING|FAIL' "$W/p1.out" | tr '\n' '|' | tail -c 400)"
fi

# ---- push 2: the same tree, every fixture skipped on its recorded pass ------------------------------------
r2="$(drive "$W/p2.out")"
if [ "$r2" = 0 ] && grep -qF 'read-set keys: 0 of 2 fixture(s) run' "$W/p2.out" && ! grep -qF '   ok    pend' "$W/p2.out"; then
  cell push2-skipped 0 "rc 0, read-set keys: 0 of 2 run, pend not dispatched"
else
  echo "CELL push2-skipped FAIL rc=$r2: the second push did not skip on the recorded pass, so the skip path was not measured: $(grep -E 'read-set|ok    |FAIL' "$W/p2.out" | tr '\n' '|' | tail -c 400)"
  exit 9
fi

if grep -qxF '   PENDING: 1 skipped on a recorded pass that printed a PENDING row: pend(recorded)=2' "$W/p2.out" \
   && ! grep -qF 'near' <<<"$(pline "$W/p2.out")"; then
  cell push2-recorded 0 "the skip path names pend(recorded)=2 and not near"
else
  cell push2-recorded 1 "" "PENDING line(s) on the skipped push: [$(pline "$W/p2.out" | tr '\n' '|')]"
fi

exit "$fail"
