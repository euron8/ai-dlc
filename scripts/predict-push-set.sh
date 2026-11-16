#!/usr/bin/env bash
# predict-push-set.sh -- the fixture set a push of <tree> would run, decided by the hook's own composer, read-only.
#
#   bash scripts/predict-push-set.sh <tree> <empty out dir>
#
# <tree> is the root of a worktree at the sha to be pushed (clean, detached at it, as the push requires). The run
# sources <tree>/.githooks/pre-push's FIXTURE_POOL span and its fxcount_arm function -- the hook's own bytes, never a
# second implementation -- and runs apply_readset_skip over every fixture directory, against COPIES of the shared key
# records and the v2 verified record (the hook's RECORD_HOME span resolves both) placed in <out dir>; where a shared
# record is absent, apply_readset_skip's own one-time import copies the git dir's legacy record into <out dir> instead.
# The counted verdict store is the one fxcount_arm names, read and never written; fxcount_arm's scratch directory
# lands under <out dir>. Nothing under the git directory and nothing in the store is written.
#
# Output: the counted store, the number of fixture directories listed, the hook's read-set and verdict-store lines,
# `RUN <n>`, then one `run <fixture>` line per fixture the push would run. <out dir>/run holds the `.kdec` rows.
# Then the consumer layout, decided by scripts/census-consumer-layout.sh --predict (the hook's own cl_select over a
# scratch install of <tree>, the shared uncounted verdict store base and the placement records, read-only), handed
# <out dir>/out as AI_DLC_CL_DIST_OUT so it takes the hook's distribution-twin skip on the decisions printed above: the
# hook's consumer-layout line, the line naming every unit that skip took, its verdict-store line naming every `<fixture>@consumer` unit skipped on a store entry or an
# unconfirmed placement record (the gate prints the same line), `CONSUMER <m>`, and one `run <fixture>@consumer` line per unit the push would run as
# `<fixture>@consumer`. `bash scripts/seed-verdict-store.sh <fixture>@consumer ...` seeds exactly those units.
# Exit 0 = predicted; 2 = could not predict (bad arguments, a non-empty out dir, no hook span, no fixture listed,
# arming or the composer failed).
set -u
[ "$#" -eq 2 ] || { echo "usage: bash scripts/predict-push-set.sh <tree> <empty out dir>" >&2; exit 2; }
T="$1"; O="$2"
[ -f "$T/.githooks/pre-push" ] || { echo "predict-push-set: $T/.githooks/pre-push is absent" >&2; exit 2; }
mkdir -p "$O" || exit 2
[ -z "$(ls -A "$O")" ] || { echo "predict-push-set: $O is not empty" >&2; exit 2; }
O="$(cd "$O" && pwd -P)" || exit 2
mkdir -p "$O/out" "$O/tmp" || exit 2
cd "$T" || exit 2
sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' .githooks/pre-push > "$O/pool.sh"
awk '/^fxcount_arm\(\) \{/ { on = 1 } on { print } on && /^}/ { exit }' .githooks/pre-push >> "$O/pool.sh"
grep -q '^apply_readset_skip() {' "$O/pool.sh" && grep -q '^fxcount_arm() {' "$O/pool.sh" \
  || { echo "predict-push-set: the hook's FIXTURE_POOL span or fxcount_arm could not be extracted" >&2; exit 2; }
# shellcheck disable=SC1091
. "$O/pool.sh"
POOL_DEPTH_IN=0
TMPDIR="$O/tmp" fxcount_arm > "$O/arm.out" 2>&1 || { cat "$O/arm.out" >&2; echo "predict-push-set: arming failed" >&2; exit 2; }
echo "store: ${AI_DLC_VERDICT_STORE#"$HOME"/}"
if [ -d "$KEYS_DIR" ]; then mkdir -p "$O/keys" && cp -R "$KEYS_DIR/." "$O/keys/" || exit 2; fi
if [ -f "$VERIFIED_RECORD" ] && [ -f "$VERIFIED_FORMAT" ]; then
  cp "$VERIFIED_RECORD" "$O/verified" && cp "$VERIFIED_FORMAT" "$O/verified.format" || exit 2
fi
KEYS_DIR="$O/keys"; VERIFIED_RECORD="$O/verified"; VERIFIED_FORMAT="$O/verified.format"
for d in "$FXROOT"*/; do [ -f "$d/run.sh" ] && printf '%s\n' "$d"; done > "$O/list"
n="$(grep -c . "$O/list")" || n=0
[ "$n" -gt 0 ] || { echo "predict-push-set: no fixture directory listed under $FXROOT" >&2; exit 2; }
echo "listed $n"
AI_DLC_READSET_LIVE_TRACE=0 apply_readset_skip "$O/list" "$O/out" > "$O/ann" 2>&1; rc=$?
[ -s "$O/out/.kdec" ] || { cat "$O/ann" >&2; echo "predict-push-set: the composer wrote no decisions (rc $rc)" >&2; exit 2; }
grep -E 'read-set keys:|verdict store: [0-9]+ fixture' "$O/ann"
awk -F'\t' '$2 == "run"' "$O/out/.kdec" > "$O/run"
echo "RUN $(grep -c . "$O/run" || true)"
awk -F'\t' '{ print "run " $1 }' "$O/run"
[ -f scripts/census-consumer-layout.sh ] || { echo "predict-push-set: $T has no scripts/census-consumer-layout.sh" >&2; exit 2; }
TMPDIR="$O/tmp" AI_DLC_CL_DIST_OUT="$O/out" bash scripts/census-consumer-layout.sh --predict > "$O/consumer.out" 2> "$O/consumer.err" < /dev/null \
  && grep -q '^CONSUMER [0-9][0-9]*$' "$O/consumer.out" \
  || { cat "$O/consumer.err" >&2; echo "predict-push-set: the consumer-layout selection failed" >&2; exit 2; }
grep -v '^   \.\.      ' "$O/consumer.out" | grep -v '^tree: '
exit 0
