#!/usr/bin/env bash
# BL-792 receipt. Usage: bash receipt-bl792.sh [<validate-mandatory-rules.sh>]
# Drives Check 5 over a seeded web/** sprint whose gate-log section carries one Notes cell per case,
# and reads the CHECK 5 line.
# 0 = a could-not-run playwright row FAILs alone (i) and PASSes beside USER-CONFIRMED (ii), a run row
#     with its .zip trace PASSes (iii), no playwright FAILs (iv), and both near-misses FAIL: a
#     "no trace captured" row (v) and a playwright line carrying xzip with no .zip (vi).
# 1 = a case answered wrong (the bare grep -qi playwright, or a match keyed on `trace`, fails here).
# 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
SUBJ="${1:-core/scripts/validate-mandatory-rules.sh}"
[ -n "${1:-}" ] || [ -f "$SUBJ" ] || SUBJ=scripts/ai-dlc/validate-mandatory-rules.sh
[ -f "$SUBJ" ] || { echo "REFUSED: no subject at $SUBJ" >&2; exit 9; }
case "$SUBJ" in /*) ;; *) SUBJ="$(pwd -P)/$SUBJ" ;; esac
# The resolver comes from beside the subject, else from either shipped layout under the cwd; the
# schema from either layout under the cwd (never by walking up from the subject).
VAA=""; SCH=""
for d in "$(dirname "$SUBJ")" "$(pwd -P)/core/scripts" "$(pwd -P)/scripts/ai-dlc"; do
  [ -z "$VAA" ] && [ -f "$d/validate-audit-anchors.sh" ] && VAA="$d/validate-audit-anchors.sh"
done
for f in "$(pwd -P)/core/schemas/audit-anchors.json" "$(pwd -P)/.claude/schemas/audit-anchors.json"; do
  [ -z "$SCH" ] && [ -f "$f" ] && SCH="$f"
done
[ -n "$VAA" ] || { echo "REFUSED: no validate-audit-anchors.sh beside $SUBJ or under the cwd" >&2; exit 9; }
[ -n "$SCH" ] || { echo "REFUSED: no audit-anchors.json schema found" >&2; exit 9; }
W="$(mktemp -d)" || exit 9
W="$(cd "$W" && pwd -P)"
mkdir -p "$W/bin" "$W/schemas" "$W/repo" || exit 9
cp "$SUBJ" "$W/bin/validate-mandatory-rules.sh" && cp "$VAA" "$W/bin/" && cp "$SCH" "$W/schemas/" || exit 9
printf '#!/bin/sh\nexit 0\n' > "$W/bin/validate-retro-evidence.sh"
printf '#!/bin/sh\nexit 0\n' > "$W/bin/validate-cycle-commits.sh"
R="$W/repo"
( cd "$R" && git -c init.defaultBranch=main init -q . && git config user.email r@example.com \
  && git config user.name Receipt && git config commit.gpgsign false \
  && echo seed > seed.txt && git add seed.txt && git commit -q -m base ) >/dev/null 2>&1 || exit 9
BASE="$(git -C "$R" rev-parse HEAD)" || exit 9
( cd "$R" && mkdir -p web/src && echo ui > web/src/app.jsx && git add web/src/app.jsx \
  && git commit -q -m "web change" ) >/dev/null 2>&1 || exit 9
mkdir -p "$R/_bmad-output/implementation-artifacts"
printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$BASE" > "$R/_bmad-output/audit-anchors.md"
c5() { # c5 <notes cell> -> PASS | FAIL | none
  printf '## Gate Log: Sprint 900\n\n| Gate | Result | Notes |\n|------|--------|-------|\n| Deploy Status Report | PASS | %s |\n' \
    "$1" > "$R/_bmad-output/implementation-artifacts/gate-log.md"
  local l
  l="$( ( cd "$R" && bash "$W/bin/validate-mandatory-rules.sh" 900 2>/dev/null ) | grep -i 'CHECK 5:' | head -1 )"
  case "$l" in *PASS*) echo PASS ;; *FAIL*) echo FAIL ;; *) echo none ;; esac
}
want="i:FAIL ii:PASS iii:PASS iv:FAIL v:FAIL vi:FAIL"
got="i:$(c5 'playwright: could not run (no webServer)')"
got="$got ii:$(c5 'playwright: could not run (no webServer); USER-CONFIRMED visual verification captured')"
got="$got iii:$(c5 'playwright: npx playwright test --trace on, trace test-results/x-trace.zip, 3 passed')"
got="$got iv:$(c5 'deploy completed')"
got="$got v:$(c5 'playwright: could not run, no trace captured')"
got="$got vi:$(c5 'playwright: run recorded, trace at test-results/x-xzip')"
case "$got" in *none*) echo "REFUSED: Check 5 printed no PASS/FAIL line on some case [$got]" >&2; exit 9 ;; esac
[ "$got" = "$want" ] || { echo "FAIL: expected [$want], got [$got]" >&2; exit 1; }
echo "PASS: Check 5 accepts playwright only beside a .zip trace, keeps USER-CONFIRMED, and refuses both near-misses [$got]"
exit 0
