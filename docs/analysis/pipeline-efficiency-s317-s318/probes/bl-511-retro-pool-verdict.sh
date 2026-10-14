#!/usr/bin/env bash
# BL-511 receipt probe: does retro's artifact-size audit take a hard verdict on an over-budget
# WHOLE-READ POOL that no OPEN carry-over item records, and release it once one does?
#
# The invocation is READ FROM retro.md, not written here: the probe extracts the
# `validate-artifact-budget.sh ...` command line from steps/retro.md §4a and drives it. So the
# step file and the validator are both under test -- a retro that stops hardening the pool, or a
# validator that ignores the token, each reads live.
#
#   PRECONDITION  retro.md names an audit command                         else 9
#   SUBJECT 1     pool OVER, backlog with no OPEN item citing WHOLE-READ-POOL -> must exit 1
#   SUBJECT 2     the same tree plus an OPEN item citing WHOLE-READ-POOL      -> must exit 0
#   CONTROL       an OPEN item NOT citing it and a CLOSED item citing it are in SUBJECT 1's
#                 backlog, so a fix keyed on "any OPEN item" or "any citing item" reads live
#
# The pool is forced over with AI_DLC_READER_WINDOW_TOKENS=200000 (pool 66,000) and 300,000
# bytes of prd.md (75,000 tok, past the 72,600 ceiling). exit 0 fixed, 1 live, 9 precondition.
set -u
V=core/scripts/validate-artifact-budget.sh
RETRO=core/skills/ai-dlc/steps/retro.md
[ -f "$V" ] && [ -f "$RETRO" ] || exit 9
CMD="$(grep -m1 -E '^[[:space:]]+scripts/ai-dlc/validate-artifact-budget\.sh --warn-only' "$RETRO")"
[ -n "$CMD" ] || exit 9
ARGS="${CMD#*validate-artifact-budget.sh}"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
d=$(mktemp -d)
P="$d/_bmad-output/planning-artifacts"
mkdir -p "$P" "$d/.claude"
head -c 300000 /dev/zero | tr '\0' 'x' > "$P/prd.md"
printf '# backlog\n### CO-S1-OTHER\n**Status:** OPEN\nunrelated\n### CO-S1-WHOLE-READ-POOL-OLD\n**Status:** CLOSED\n' > "$P/carry-over-backlog.md"
run() {
  # shellcheck disable=SC2086
  AI_DLC_READER_WINDOW_TOKENS=200000 bash "$V" --root "$d" $ARGS > "$d/out" 2>&1
}
run
[ $? -eq 1 ] || exit 1
# Refused for the RIGHT reason: the pool row was reported and the pool remedy printed. A
# validator that dies earlier (a failing self-probe) exits 1 too and must not score fixed.
grep -q '^OVER  WHOLE-READ POOL' "$d/out" || exit 1
grep -q 'no OPEN carry-over item cites it' "$d/out" || exit 1
printf '### CO-S1-WHOLE-READ-POOL-OVER pool 75000 tok\n**Status:** OPEN\nartifact-consolidation.md owed before route\n' >> "$P/carry-over-backlog.md"
run || exit 1
exit 0
