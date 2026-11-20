#!/bin/bash
# seed-verdict-store.sh -- pre-seed the COUNTED verdict store that a push reads.
#
#   bash scripts/seed-verdict-store.sh [--keep <dir>] [--jobs <n>] [--dirty-ok] <fixture>[@consumer] [...]
#
# Run from the ROOT of a clean worktree detached at the exact sha to be pushed. Each named fixture runs through
# core/scripts/hermetic-run.sh with the invocation counter armed, so every pass is recorded in
# <store>/counted-<vk>, the one store the hook's push reads (.githooks/pre-push, "2f. THE INVOCATION BUDGET").
# Every fixture runs as a pool unit does: PREPUSH_POOL_DEPTH=1 (a fixture that drives a hook opens a nested pool of
# at most two workers) and stdin /dev/null. --jobs <n> runs <n> of them at once (xargs -P; default 1); <n> is 1 to
# 99999, anything else a refusal, since BSD `xargs -P 0` is unlimited. Each unit writes its own rc file, and every
# fixture must have one, so a unit that died without one is a refusal (exit 2), never a pass.
# A name ending `@consumer` is a unit scripts/predict-push-set.sh prints as `run <fixture>@consumer`: it is run by
# scripts/census-consumer-layout.sh --only (the hook's own cl_select and cl_publish over a scratch install, uncounted,
# into the shared store base and the placement records a push reads), and printed as `<fixture>@consumer rc=<n>`; a
# name the selection no longer holds prints `<fixture>@consumer not-selected (record current; nothing ran)`, never an
# rc line, and is not a failure. Names are run in two groups, the plain
# ones first.
# Before any unit runs the script waits, printing why, while a push gate runs in this repository (scripts/gate-wait.sh).
# --dirty-ok seeds from a work tree with uncommitted changes. hermetic-run.sh copies the sandbox from the work tree
# and keys the entry on the same work tree (hr_population refuses when the copy population and the key manifest
# disagree), so a dirty pass is recorded under the content that ran, which a push of a different tree never matches.
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
# Output: the counted store dir once, then one `<fx> rc=<n>` line per fixture, in argument order. Exit 0 only if
# every fixture passed; exit 1 on any red; exit 2 on a refusal (dirty tree without --dirty-ok, no fixture, a name
# given twice or not a plain name, a bad --jobs, wrong cwd, arming not extractable or failed, a unit with no rc).
# Honours AI_DLC_VERDICT_STORE as the BASE (default ~/.cache/ai-dlc/verdicts), like the hook.
#
# --keep <dir>: each fixture's whole output is also copied to <dir>/<fixture>.out (scripts/pregate-self-check.sh
# reads the judge's pass line there). A copy that fails is a refusal.
svs_main() {
set -u
# STDIN IS /dev/null FOR THE WHOLE RUN, as the push's pool gives every fixture (xargs children, and its worker's
# `< /dev/null`). bash 3.2 skips BASH_ENV in a `bash -c` at shell level 1 whose stdin is an inet socket, and the
# counter rides BASH_ENV. A session's Bash tool hands its commands such a stdin; inside a fixture, a `bash -c` reached
# through `exec` (which lowers SHLVL) or `env -i`, run in the foreground or as a `set -m` job, inherits it and goes
# uncounted, so an invocations.decl row set from a hand seed reads low against the push (BL-1053).
exec < /dev/null
keep=""; jobs=1; dirty_ok=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --keep) keep="${2:-}"; [ -n "$keep" ] && [ -d "$keep" ] || { echo "seed-verdict-store: --keep needs an existing directory" >&2; exit 2; }; shift 2 ;;
    --jobs) jobs="${2:-}"; shift; [ "$#" -gt 0 ] && shift ;;
    --dirty-ok) dirty_ok=1; shift ;;
    *) break ;;
  esac
done
[ "$#" -gt 0 ] || { echo "usage: bash scripts/seed-verdict-store.sh [--keep <dir>] [--jobs <n>] [--dirty-ok] <fixture>[@consumer] [...]" >&2; exit 2; }
case "$jobs" in ''|*[!0-9]*|??????*) echo "seed-verdict-store: --jobs wants 1 to 99999, got '$jobs'" >&2; exit 2 ;; esac
[ "$((10#$jobs))" -ge 1 ] || { echo "seed-verdict-store: --jobs wants 1 to 99999, got '$jobs'" >&2; exit 2; }
jobs=$((10#$jobs))
seen=" "
for fx in "$@"; do
  case "${fx%@consumer}" in ''|*[!A-Za-z0-9._-]*|.*) echo "seed-verdict-store: '$fx' is not a fixture name" >&2; exit 2 ;; esac
  case "$seen" in *" $fx "*) echo "seed-verdict-store: $fx is named twice" >&2; exit 2 ;; esac
  seen="$seen$fx "
done
HOOK="$PWD/.githooks/pre-push"
[ -f "$HOOK" ] && [ -f "$PWD/core/scripts/hermetic-run.sh" ] \
  || { echo "seed-verdict-store: run from the root of a worktree (no .githooks/pre-push or core/scripts/hermetic-run.sh here)" >&2; exit 2; }
st="$(git status --porcelain)" || { echo "seed-verdict-store: git status failed" >&2; exit 2; }
[ -z "$st" ] || [ "$dirty_ok" = 1 ] || { echo "seed-verdict-store: worktree is dirty; seed from a clean worktree detached at the pushed sha" >&2; exit 2; }
work="$(mktemp -d "${TMPDIR:-/tmp}/seedvs.XXXXXX")" || exit 2
trap 'rm -rf "$work"' EXIT
awk '/^fxcount_arm\(\) \{/ { on = 1 } on { print } on && /^}/ { exit }' "$HOOK" > "$work/arm.sh"
if [ ! -s "$work/arm.sh" ] || ! grep -q '^fxcount_arm() {' "$work/arm.sh" || ! grep -q 'vk=' "$work/arm.sh"; then
  echo "seed-verdict-store: could not extract fxcount_arm from $HOOK" >&2; exit 2
fi
# shellcheck disable=SC1090
. "$work/arm.sh" || exit 2
if [ -f "$PWD/scripts/gate-wait.sh" ]; then . "$PWD/scripts/gate-wait.sh" && gate_wait seed-verdict-store; else echo "seed-verdict-store: wait skipped, no scripts/gate-wait.sh here, so a running push gate is not checked"; fi
POOL_DEPTH_IN=0
fxcount_arm > "$work/arm.out" 2>&1 || { cat "$work/arm.out" >&2; echo "seed-verdict-store: arming failed" >&2; exit 2; }
case "${AI_DLC_VERDICT_STORE:-}" in */counted-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;; *) echo "seed-verdict-store: arming set no counted store" >&2; exit 2 ;; esac
echo "counted store: $AI_DLC_VERDICT_STORE"
# ONE UNIT, ONE RC FILE. xargs's own exit lumps several causes together (123, 124, 125), so it is not read: each
# unit writes <fx>.rc as its last act, and the report below requires one per fixture.
cat > "$work/unit.sh" <<'UNIT_END'
w="$1"; k="$2"; fx="$3"
PREPUSH_POOL_DEPTH=1 bash core/scripts/hermetic-run.sh "$fx" > "$w/$fx.out" 2>&1 < /dev/null; rc=$?
if [ -n "$k" ]; then cp "$w/$fx.out" "$k/$fx.out" || rc=keep; fi
printf '%s\n' "$rc" > "$w/$fx.rc"
UNIT_END
# `<fx>@consumer` names are split off here and run last, by the census; the plain names keep the loop below.
cons=""; plain=""
for fx in "$@"; do
  case "$fx" in *@consumer) cons="$cons ${fx%@consumer}" ;; *) plain="$plain $fx" ;; esac
done
# shellcheck disable=SC2086
set -- $plain
[ "$#" -eq 0 ] || printf '%s\n' "$@" | xargs -P "$jobs" -n 1 bash "$work/unit.sh" "$work" "$keep"
fail=0
for fx in "$@"; do
  rc="$(cat "$work/$fx.rc" 2>/dev/null)" || rc=""
  case "$rc" in
    keep) echo "seed-verdict-store: could not keep $fx's output in $keep" >&2; exit 2 ;;
    ''|*[!0-9]*) echo "seed-verdict-store: $fx's unit left no rc, so it gave no verdict" >&2; exit 2 ;;
  esac
  printf '%s rc=%s\n' "$fx" "$rc"
  if [ "$rc" != 0 ]; then
    fail=1
    # A red prints the verdict lines (never a bare tail, which hid the J3 rows above it), plus the hermetic-run trailer;
    # with no verdict line at all it prints the whole output. The verdict lines include a fixture's evidence lines, the
    # ones indented `      | ` under its FAIL line (A00's stderr print and cwd_why in enforcement-map-sites, among others).
    if grep -Eq 'FAIL|J[1-5]|BROKEN|ERROR|REQUIRED input' "$work/$fx.out"; then
      grep -E "FAIL|J[1-5]|BROKEN|ERROR|REQUIRED input|^hermetic-run: $fx: rc=|^      [|] " "$work/$fx.out"
    else cat "$work/$fx.out"; fi
  fi
done
if [ -n "$cons" ]; then
  cdo=""; [ "$dirty_ok" != 1 ] || cdo=--dirty-ok
  # shellcheck disable=SC2086
  bash scripts/census-consumer-layout.sh --only "$cons" --jobs "$jobs" $cdo > "$work/cons.out" 2>&1 < /dev/null; crc=$?
  if [ -n "$keep" ]; then cp "$work/cons.out" "$keep/consumer.out" || { echo "seed-verdict-store: could not keep the consumer output in $keep" >&2; exit 2; }; fi
  for fx in $cons; do
    if grep -qxF "${fx}@consumer ok" "$work/cons.out"; then printf '%s@consumer rc=0\n' "$fx"
    elif grep -qF "${fx}@consumer not selected" "$work/cons.out"; then printf '%s@consumer not-selected (record current; nothing ran)\n' "$fx"
    elif grep -qxF "${fx}@consumer FAIL" "$work/cons.out"; then printf '%s@consumer rc=1\n' "$fx"; fail=1
    else echo "seed-verdict-store: ${fx}@consumer gave no verdict (census exit $crc):" >&2; tail -n 8 "$work/cons.out" >&2; exit 2; fi
  done
  [ "$fail" = 0 ] || grep -E '^census: |^--- |^ ' "$work/cons.out"
fi
exit "$fail"
}
# Loadable: sourced, this file defines svs_main and runs nothing; executed, it runs it (core/fixtures/lib/inproc.sh).
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
svs_main "$@"
