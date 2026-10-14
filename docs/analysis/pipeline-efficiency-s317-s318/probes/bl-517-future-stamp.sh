#!/usr/bin/env bash
# BL-517 receipt probe: does validate-artifact-budget.sh (the program gate Check 14 and route
# Step 0a run on the snapshot) refuse a stamp more than 10 minutes after now, wherever it sits
# in a Recent Activity line or an In-Flight `dispatched-at` cell, accept the forms a real
# snapshot carries that are not a single instant, and does the remedy reach the lead THROUGH
# verdict.sh, the wrapper every lead-facing call site uses?
#
#   SUBJECTS  (each its own run, each must exit 1 with a FUTURE row naming the stamp)
#             a leading Recent Activity stamp 60 min ahead; the same stamp MID-LINE; one
#             followed by ` - DEPLOY DONE`; a `dispatched-at` cell 60 min ahead; and a CLOCK
#             CORRECTION line naming the old stamp in FULL ISO form (it is itself future)
#   CONTROLS  (each its own run, each must exit 0; one refused = an over-broad fix, exit 1)
#             ranges `T09:55-10:45Z` / `T12:00Z-12:45Z`, spaced ranges ` - `, ` to `, arrow,
#             en dash before a digit, a date-only stamp, an `x` placeholder, a stamp 5 min
#             ahead, a future `since` in the In-Flight STATUS cell, and a CLOCK CORRECTION line
#             naming the old stamps as bare HH:MMZ (the remedy's own form)
#   WRAPPER   five future stamps plus a gate-log over budget, driven through verdict.sh: the
#             wrapper's capped output must carry the remedy line and all five FUTURE rows
#
# Now is pinned with AI_DLC_SNAPSHOT_NOW_EPOCH=1791975600 (2026-10-14T11:00:00Z). A validator
# that ignores the pin reads the real clock, past which every seeded stamp lies, and each
# SUBJECT then exits 0 -> probe exit 1, never a false pass.
#
# exit 0 fixed, 1 live (or over-broad), 9 precondition missing. Run from the repo root.
set -u
V=core/scripts/validate-artifact-budget.sh
W=core/scripts/verdict.sh
[ -f "$V" ] && [ -f "$W" ] || exit 9
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
VD="$(cd "$(dirname "$V")" && pwd)"
d=$(mktemp -d)
mkdir -p "$d/_bmad-output" "$d/.claude"
H='agent | role | deliverable | dispatched-at | status
--- | --- | --- | --- | ---'
seed() {
  printf '## Pipeline Position\n- p\n## Sprint Context\n- s\n## Recent Activity\n%s\n## Open Items\n- none\n## Locked Decisions\n- k\n## In-Flight Teammates\n%s\n## Context Reminders\n- c\n' \
    "$1" "$2" > "$d/_bmad-output/pipeline-snapshot.md"
}
run() { AI_DLC_SNAPSHOT_NOW_EPOCH=1791975600 bash "$V" --root "$d" --only pipeline-snapshot.md > "$d/out" 2>&1; }
# A clean past entry must pass. A validator that refuses it -- including one whose own
# self-probe now fails -- is broken, which is LIVE (1), not a missing precondition.
seed '- 2026-10-14T10:00Z past entry' "$H"
run || exit 1
while IFS='|' read -r ra row; do
  seed "$ra" "$H${row:+
$row}"
  run || exit 1
done <<'C'
- 2026-10-14T09:55-10:45Z window and 2026-10-14T12:00Z-12:45Z plan|
- 2026-10-14T12:00Z - 12:45Z, 2026-10-14T12:00Z to 12:45Z, 2026-10-14T12:00Z → 12:45Z, 2026-10-14T12:00Z – 12:45Z plan|
- 2026-10-15 date only|
- 2026-10-14Txx:xxZ placeholder|
- 2026-10-14T11:05Z five minutes ahead|
- 2026-10-14T10:58Z CLOCK CORRECTION: rewrote 2 future stamp(s) to date -u: 12:00Z, 12:45Z|
- ok|dev-a | dev | s1 | 2026-10-14T10:00Z | in-flight, since 2026-10-14T23:00Z
C
while IFS='|' read -r ra row; do
  seed "$ra" "$H${row:+
$row}"
  run
  [ $? -eq 1 ] && grep -q '^FUTURE .*2026-10-14T12:00Z' "$d/out" || exit 1
done <<'S'
- 2026-10-14T12:00Z DEPLOY DONE|
- DEPLOY DONE at 2026-10-14T12:00Z|
- 2026-10-14T12:00Z - DEPLOY DONE|
- ok|dev-a | dev | s1 | 2026-10-14T12:00Z | in-flight
- 2026-10-14T10:58Z CLOCK CORRECTION: rewrote 1 future stamp(s) to date -u: 2026-10-14T12:00Z|
S
# The wrapper arm: the remedy and every row must survive verdict.sh's line cap beside an OVER.
head -c 200000 /dev/zero | tr '\0' 'x' > "$d/_bmad-output/gate-log.md"
seed '- 2026-10-14T12:00Z DEPLOY DONE
- 2026-10-14T12:05Z MERGED
- 2026-10-14T12:10Z HANDOFF
- 2026-10-14T12:15Z DISPATCHED dev
- 2026-10-14T12:20Z GATE PASS' "$H"
( cd "$d" && AI_DLC_SNAPSHOT_NOW_EPOCH=1791975600 AI_DLC_SCRIPTS_DIR="$VD" \
    bash "$VD/verdict.sh" validate-artifact-budget --root "$d" ) > "$d/wout" 2>&1
[ $? -eq 1 ] || exit 1
grep -q 'CLOCK CORRECTION' "$d/wout" || exit 1
grep -q 'bare HH:MMZ' "$d/wout" || exit 1
[ "$(grep -c 'FUTURE  _bmad-output/pipeline-snapshot.md line' "$d/wout")" = "5" ] || exit 1
exit 0
