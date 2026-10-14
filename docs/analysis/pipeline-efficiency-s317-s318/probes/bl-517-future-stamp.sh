#!/usr/bin/env bash
# BL-517 receipt probe: does validate-artifact-budget.sh (the program gate Check 14 and route
# Step 0a run on the snapshot) refuse a Recent Activity stamp more than 10 minutes after now,
# while accepting the forms a real snapshot carries that are not a single instant?
#
#   SUBJECT   a Recent Activity line stamped 60 min after the pinned now -> must exit 1
#   CONTROLS  (each its own run, each must exit 0; one refused = an over-broad fix, exit 1)
#             a range `T09:55-10:45Z` / `T12:00Z-12:45Z`, a date-only stamp, an `x` placeholder,
#             a stamp 5 min ahead, a future `since` in the In-Flight STATUS cell
#
# Now is pinned with AI_DLC_SNAPSHOT_NOW_EPOCH=1791975600 (2026-10-14T11:00:00Z). A validator
# that ignores the pin reads the real clock, past which every seeded stamp lies, and the
# SUBJECT then exits 0 -> probe exit 1, never a false pass.
#
# exit 0 fixed, 1 live (or over-broad), 9 precondition missing. Run from the repo root.
set -u
V=core/scripts/validate-artifact-budget.sh
[ -f "$V" ] || exit 9
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
d=$(mktemp -d)
mkdir -p "$d/_bmad-output" "$d/.claude"
H='agent | role | deliverable | dispatched-at | status
--- | --- | --- | --- | ---'
seed() {
  printf '## Pipeline Position\n- p\n## Sprint Context\n- s\n## Recent Activity\n%s\n## Open Items\n- none\n## Locked Decisions\n- k\n## In-Flight Teammates\n%s\n## Context Reminders\n- c\n' \
    "$1" "$2" > "$d/_bmad-output/pipeline-snapshot.md"
}
run() { AI_DLC_SNAPSHOT_NOW_EPOCH=1791975600 bash "$V" --root "$d" --only pipeline-snapshot.md >/dev/null 2>&1; }
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
- 2026-10-15 date only|
- 2026-10-14Txx:xxZ placeholder|
- 2026-10-14T11:05Z five minutes ahead|
- ok|dev-a | dev | s1 | 2026-10-14T10:00Z | in-flight, since 2026-10-14T23:00Z
C
seed '- 2026-10-14T12:00Z DEPLOY DONE' "$H"
AI_DLC_SNAPSHOT_NOW_EPOCH=1791975600 bash "$V" --root "$d" --only pipeline-snapshot.md > "$d/out" 2>&1
[ $? -eq 1 ] && grep -q '^FUTURE .*2026-10-14T12:00Z' "$d/out" && exit 0
exit 1
