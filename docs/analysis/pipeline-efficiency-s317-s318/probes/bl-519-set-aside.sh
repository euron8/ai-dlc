#!/usr/bin/env bash
# BL-519 receipt probe: does the shipped join-remediator-shards.sh refuse a `repaired` MAJOR whose
# claim sets part of the fix aside as outside the shard / not required, accept the same fix split
# into a repaired entry plus an escalated remainder, and route that remainder by printing it?
#
#   OFFENDER  graph s318 stories-party-repair-p1/5.md:111 (sm-05 F-3), verbatim claim text
#             -> must REFUSE naming the entry
#   TWIN      the same entry split, the remainder `escalated` under the same source
#             -> must JOIN and print `ESCALATED: 01.md <entry>` and `ESCALATED-COUNT: 1`
# exit 0 fixed, 1 live (either world answers the wrong way), 9 precondition missing.
# Measured at 0.781.0 (origin/main fe7d5ec2): OFFENDER joins -> exit 1. Run from the repo root.
set -u
J="$(pwd)/core/scripts/join-remediator-shards.sh"; H="$(pwd)/core/hooks/ai-dlc-gate-remediation-guard.sh"
[ -f "$J" ] && [ -f "$H" ] || exit 9
command -v jq >/dev/null 2>&1 || exit 9
SLOT=_bmad-output/planning-artifacts/s305
world() { # -> a project root whose story a.md was edited by one dispatched agent
  local w; w="$(mktemp -d)" || exit 9
  mkdir -p "$w/$SLOT/stories" "$w/$SLOT/shards/stories-repair-p1" "$w/_bmad-output/gate-adjudication" || exit 9
  printf '# Pipeline Snapshot\n' > "$w/_bmad-output/pipeline-snapshot.md"
  printf 'story\n' > "$w/$SLOT/stories/a.md"
  jq -nc --arg f "$w/$SLOT/stories/a.md" \
    '{session_id:"t", tool_name:"Edit", transcript_path:"", tool_input:{file_path:$f}, agent_id:"a16fddf14ea289491"}' \
    | CLAUDE_PROJECT_DIR="$w" bash "$H" >/dev/null 2>&1
  [ -f "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl" ] || exit 9
  printf '%s' "$w"
}
head_part() { # <claim tail>
  printf '### stories-sm-05.md#F-3 — MAJOR\n- source: stories-sm-05.md#F-3\n- disposition: repaired\n- edit: %s/stories/a.md:84\n- derivation: n/a (no factual claim)\n' "$SLOT"
  printf -- '- claim now asserted: The operator records the `sweep_id` from the 200 response body of the press, which Story 1.3 answers, so conjunct 4 is kept. %s\n' "$1"
}
join() { # <world> -> RC, OUT
  OUT="$(AI_DLC_PROJECT_ROOT="$1" bash "$J" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z 2>&1)"; RC=$?
}
P=shards/stories-repair-p1/01.md
w="$(world)"
{ head_part 'A dashboard display of the returned id in Story 1.4 is outside this shard and is escalated in the entry below.'
  printf '\n### stories-sm-05.md#F-3 (remainder) — MAJOR\n- source: stories-sm-05.md#F-3\n- disposition: escalated\n- edit: n/a (escalated: Story 1.4, outside this shard)\n- derivation: n/a (no factual claim)\n'; } > "$w/$SLOT/$P"
join "$w"
[ "$RC" -eq 0 ] || exit 1
case "$OUT" in *"ESCALATED: 01.md stories-sm-05.md#F-3 (remainder) — MAJOR"*"ESCALATED-COUNT: 1"*) ;; *) exit 1 ;; esac
w="$(world)"
head_part 'A dashboard display of the returned id in Story 1.4 would be more ergonomic on iOS but is outside this shard and is not required for the AC to hold.' > "$w/$SLOT/$P"
join "$w"
[ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"01.md:1: the stories-sm-05.md#F-3 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside"*) exit 0 ;; esac
exit 1
