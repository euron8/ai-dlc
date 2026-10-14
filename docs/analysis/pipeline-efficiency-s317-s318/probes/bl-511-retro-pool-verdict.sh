#!/usr/bin/env bash
# BL-511 receipt probe: does retro take a hard verdict on an over-budget WHOLE-READ POOL that no
# OPEN carry-over item records, and release it once one does -- at BOTH sites retro runs the
# audit: §4a (the artifact-size audit) and §5c (the pre-commit gate that blocks Step 6)?
#
# The invocations are READ FROM retro.md, not written here: the probe extracts the
# `scripts/ai-dlc/validate-artifact-budget.sh --warn-only ...` command from the §4a section
# (`### 4a.` to `### 4b.`) and from the §5c section (`### 5c.` to the next `### `), strips the
# backticks and a trailing period, and drives each one. So the step file and the validator are
# both under test -- a retro whose either site stops hardening the pool, or a validator that
# ignores the token, each reads live.
#
#   PRECONDITION  retro.md has a §4a audit command                                  else 9
#   LIVE          §5c names no audit command                                        -> 1
#   SUBJECT 1     pool OVER, backlog with no OPEN item citing WHOLE-READ-POOL -> each must exit 1
#   SUBJECT 2     the same tree plus an OPEN item citing WHOLE-READ-POOL      -> each must exit 0
#   CONTROL       an OPEN item NOT citing it and a CLOSED item citing it are in SUBJECT 1's
#                 backlog, so a fix keyed on "any OPEN item" or "any citing item" reads live
#
# The pool is forced over with AI_DLC_READER_WINDOW_TOKENS=200000 (pool 66,000) and 300,000
# bytes of prd.md (75,000 tok, past the 72,600 ceiling). exit 0 fixed, 1 live, 9 precondition.
set -u
V=core/scripts/validate-artifact-budget.sh
RETRO=core/skills/ai-dlc/steps/retro.md
[ -f "$V" ] && [ -f "$RETRO" ] || exit 9
# extract <start-heading-prefix> <end-heading-prefix|ANY> -> the args after the script name
extract() {
  awk -v s="$1" -v e="$2" '
    index($0, s) == 1 { on = 1; next }
    on && /^### / && (e == "ANY" || index($0, e) == 1) { exit }
    on && /scripts\/ai-dlc\/validate-artifact-budget\.sh --warn-only/ {
      a = $0; sub(/.*validate-artifact-budget\.sh/, "", a); sub(/`.*/, "", a); sub(/\.[[:space:]]*$/, "", a)
      print a; exit
    }' "$RETRO"
}
A4="$(extract '### 4a.' '### 4b.')"
A5="$(extract '### 5c.' ANY)"
[ -n "$A4" ] || exit 9
[ -n "$A5" ] || exit 1
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
d=$(mktemp -d)
P="$d/_bmad-output/planning-artifacts"
mkdir -p "$P" "$d/.claude"
head -c 300000 /dev/zero | tr '\0' 'x' > "$P/prd.md"
printf '# backlog\n### CO-S1-OTHER\n**Status:** OPEN\nunrelated\n### CO-S1-WHOLE-READ-POOL-OLD\n**Status:** CLOSED\n' > "$P/carry-over-backlog.md"
run() { # run <args>
  # shellcheck disable=SC2086
  AI_DLC_READER_WINDOW_TOKENS=200000 bash "$V" --root "$d" $1 > "$d/out" 2>&1
}
for ARGS in "$A4" "$A5"; do
  run "$ARGS"
  [ $? -eq 1 ] || exit 1
  # Refused for the RIGHT reason: the pool row was reported and the pool remedy printed. A
  # validator that dies earlier (a failing self-probe) exits 1 too and must not score fixed.
  grep -q '^OVER  WHOLE-READ POOL' "$d/out" || exit 1
  grep -q 'no OPEN carry-over item cites it' "$d/out" || exit 1
done
printf '### CO-S1-WHOLE-READ-POOL-OVER pool 75000 tok\n**Status:** OPEN\nartifact-consolidation.md owed before route\n' >> "$P/carry-over-backlog.md"
for ARGS in "$A4" "$A5"; do
  run "$ARGS" || exit 1
done
exit 0
