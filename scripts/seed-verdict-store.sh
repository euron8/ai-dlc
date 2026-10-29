#!/bin/bash
# seed-verdict-store.sh -- pre-seed the COUNTED verdict store that a push reads.
#
#   bash scripts/seed-verdict-store.sh <fixture> [<fixture> ...]
#
# Run from the ROOT of a clean worktree detached at the exact sha to be pushed. Each named fixture runs serially
# through core/scripts/hermetic-run.sh with the invocation counter armed, so every pass is recorded in
# <store>/counted-<vk>, the one store the hook's push reads (.githooks/pre-push, "2f. THE INVOCATION BUDGET").
#
# WHY NOT A PLAIN RUN: a plain hermetic-run.sh writes the parent store, and a run under a mktemp store writes a
# store nothing reads. A push armed with the counter reads only counted-<vk>, so neither seeds anything a push
# skips on. The arming is NOT copied here: fxcount_arm is extracted from the hook at run time (awk, from the line
# opening the function to its first closing brace) and run with POOL_DEPTH_IN=0, so the key and the store path
# are the hook's own and cannot drift from it.
#
# A RED IS NEVER RECORDED: hermetic-run.sh writes a verdict only when the fixture passed
# (`hr_rc -eq 0 && hr_missing -eq 0` guards hr_store_put), and the invocation judge runs before that write, so a
# count mismatch is the fixture's own FAIL and leaves no entry.
#
# Output: the counted store dir once, then one `<fx> rc=<n>` line per fixture. Exit 0 only if every fixture
# passed; exit 1 on any red; exit 2 on a refusal (dirty tree, no fixture, wrong cwd, arming not extractable or
# failed). Honours AI_DLC_VERDICT_STORE as the BASE (default ~/.cache/ai-dlc/verdicts), like the hook.
set -u
[ "$#" -gt 0 ] || { echo "usage: bash scripts/seed-verdict-store.sh <fixture> [<fixture> ...]" >&2; exit 2; }
HOOK="$PWD/.githooks/pre-push"
[ -f "$HOOK" ] && [ -f "$PWD/core/scripts/hermetic-run.sh" ] \
  || { echo "seed-verdict-store: run from the root of a worktree (no .githooks/pre-push or core/scripts/hermetic-run.sh here)" >&2; exit 2; }
st="$(git status --porcelain)" || { echo "seed-verdict-store: git status failed" >&2; exit 2; }
[ -z "$st" ] || { echo "seed-verdict-store: worktree is dirty; seed from a clean worktree detached at the pushed sha" >&2; exit 2; }
work="$(mktemp -d "${TMPDIR:-/tmp}/seedvs.XXXXXX")" || exit 2
awk '/^fxcount_arm\(\) \{/ { on = 1 } on { print } on && /^}/ { exit }' "$HOOK" > "$work/arm.sh"
if [ ! -s "$work/arm.sh" ] || ! grep -q '^fxcount_arm() {' "$work/arm.sh" || ! grep -q 'vk=' "$work/arm.sh"; then
  echo "seed-verdict-store: could not extract fxcount_arm from $HOOK" >&2; exit 2
fi
# shellcheck disable=SC1090
. "$work/arm.sh" || exit 2
POOL_DEPTH_IN=0
fxcount_arm > "$work/arm.out" 2>&1 || { cat "$work/arm.out" >&2; echo "seed-verdict-store: arming failed" >&2; exit 2; }
case "${AI_DLC_VERDICT_STORE:-}" in */counted-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;; *) echo "seed-verdict-store: arming set no counted store" >&2; exit 2 ;; esac
echo "counted store: $AI_DLC_VERDICT_STORE"
fail=0
for fx in "$@"; do
  bash core/scripts/hermetic-run.sh "$fx" > "$work/$fx.out" 2>&1; rc=$?
  printf '%s rc=%s\n' "$fx" "$rc"
  [ "$rc" = 0 ] || { fail=1; tail -5 "$work/$fx.out"; }
done
exit "$fail"
