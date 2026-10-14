#!/usr/bin/env bash
# BL-519 receipt probe: does the shipped join-remediator-shards.sh refuse a `repaired` MAJOR whose
# claim sets part of the fix aside as outside the shard / not required, accept the same fix split
# into a repaired entry plus an escalated remainder, and route that remainder by printing it?
#
#   OFFENDER  graph s318 stories-party-repair-p1/5.md:111 (sm-05 F-3), verbatim claim text
#             ("outside this shard and is not required")        -> must REFUSE naming the entry
#   SHARD     the same entry saying only "is outside this shard"  -> must REFUSE (the regex's first
#             half alone; an offender carrying both halves cannot tell a regex cut to either)
#   TWIN      the same entry split, the remainder `escalated` under the same source
#             -> must JOIN and print `ESCALATED: 01.md <entry>` and `ESCALATED-COUNT: 1`
#   MINOR     a repaired MINOR whose claim says "not required"   -> must JOIN (the severity gate)
#   SRC       --sources over a record: a repaired MAJOR set aside -> rc 2 naming it; a joined record
#             with the remainder escalated, a LATER half repair of it in another part under the same
#             source token (stays OPEN), and one escalation the serial remediator's `closes:` names
#             -> rc 0, the remainder open, `ESCALATED-CLOSED:` for the closed one, `ESCALATED-COUNT:
#             1 (1 closed ...)`, no SERIAL-REQUIRED line
#   TWIN also prints `SERIAL-REQUIRED: 1`: the dispatch count for the serial remediator.
# Regressions scored non-zero: closure keyed on the source: token (SRC); SERIAL-REQUIRED not printed (TWIN).
# Every parts-mode entry carries `siblings: n/a (insertion)`, so the set-aside is each world's only
# defect. exit 0 fixed, 1 live (any world answers the wrong way), 9 precondition missing.
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
head_part() { # <claim tail> [severity]
  printf '### stories-sm-05.md#F-3 — %s\n- source: stories-sm-05.md#F-3\n- disposition: repaired\n- edit: %s/stories/a.md:84\n- siblings: n/a (insertion)\n- derivation: n/a (no factual claim)\n' "${2:-MAJOR}" "$SLOT"
  printf -- '- claim now asserted: The operator records the `sweep_id` from the 200 response body of the press, which Story 1.3 answers, so conjunct 4 is kept. %s\n' "$1"
}
join() { # <world> -> RC, OUT
  OUT="$(AI_DLC_PROJECT_ROOT="$1" bash "$J" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z 2>&1)"; RC=$?
}
src() { # <body> -> RC, OUT: --sources over a record beside one seat file carrying F-1..F-3
  local w; w="$(mktemp -d)" || exit 9
  mkdir -p "$w/.claude" "$w/_bmad-output/party-mode/s305" || exit 9
  printf '# seat\n\n## F-1 (major) sections: 1\n\n## F-2 (major) sections: 1\n\n## F-3 (major) sections: 1\n' \
    > "$w/_bmad-output/party-mode/s305/stories-sm-05.md"
  printf '%b' "$1" > "$w/rec.md"
  OUT="$(AI_DLC_PROJECT_ROOT="$w" bash "$J" --sources "$w/rec.md" --sprint 305 2>&1)"; RC=$?
}
P=shards/stories-repair-p1/01.md
REFUSAL="01.md:1: the stories-sm-05.md#F-3 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside"
# TWIN
w="$(world)"
{ head_part 'A dashboard display of the returned id in Story 1.4 is outside this shard and is escalated in the entry below.'
  printf '\n### stories-sm-05.md#F-3 (remainder) — MAJOR\n- source: stories-sm-05.md#F-3\n- disposition: escalated\n- edit: n/a (escalated: Story 1.4, outside this shard)\n- derivation: n/a (no factual claim)\n'; } > "$w/$SLOT/$P"
join "$w"
[ "$RC" -eq 0 ] || exit 1
case "$OUT" in *"ESCALATED: 01.md stories-sm-05.md#F-3 (remainder) — MAJOR"*"ESCALATED-COUNT: 1"*"SERIAL-REQUIRED: 1"*) ;; *) exit 1 ;; esac
# MINOR
w="$(world)"
head_part 'The trailing clause the finding proposed is not required.' MINOR > "$w/$SLOT/$P"
join "$w"; [ "$RC" -eq 0 ] || exit 1
# SHARD
w="$(world)"
head_part 'A dashboard display of the returned id in Story 1.4 is outside this shard.' > "$w/$SLOT/$P"
join "$w"; [ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"$REFUSAL"*) ;; *) exit 1 ;; esac
# SRC: the set-aside refused in --sources mode
src '### F-3 — MAJOR\n- source: stories-sm-05.md#F-3\n- disposition: repaired\n- edit: n/a (no edit)\n- claim now asserted: the dashboard display is outside this shard and is not required.\n'
[ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"rec.md:1: the F-3 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside"*) ;; *) exit 1 ;; esac
# SRC: a joined record (shard markers). 01.md splits F-3 and escalates the remainder; 02.md, LATER,
# repairs another conjunct under the SAME source token (graph s318 dev-05#F-3's shape) and closes
# nothing; F-2 escalated in 01.md is closed by the serial remediator's `closes:` line -> F-3 open,
# F-2 printed CLOSED, count 1, 1 closed, and no SERIAL-REQUIRED line in --sources mode
src '<!-- shard: 01.md -->\n### F-3 — MAJOR\n- source: stories-sm-05.md#F-3\n- disposition: repaired\n- edit: n/a (no edit)\n- claim now asserted: the display is outside this shard; escalated below.\n\n### F-3 (remainder) — MAJOR\n- source: stories-sm-05.md#F-3\n- disposition: escalated\n- edit: n/a\n\n### F-2 — MAJOR\n- source: stories-sm-05.md#F-2\n- disposition: escalated\n- edit: n/a\n\n<!-- shard: 02.md -->\n### F-3 other conjunct — MAJOR\n- source: stories-sm-05.md#F-3\n- disposition: repaired\n- edit: n/a (no edit)\n\n### serial F-2 — MAJOR\n- source: stories-sm-05.md#F-2\n- disposition: repaired\n- edit: n/a (no edit)\n- closes: 01.md F-2 — MAJOR\n'
[ "$RC" -eq 0 ] || exit 1
case "$OUT" in *"ESCALATED: 01.md F-3 (remainder) — MAJOR"*"ESCALATED-CLOSED: 01.md F-2 — MAJOR"*"ESCALATED-COUNT: 1 (1 closed"*) ;; *) exit 1 ;; esac
case "$OUT" in *SERIAL-REQUIRED*) exit 1 ;; esac
# OFFENDER, last
w="$(world)"
head_part 'A dashboard display of the returned id in Story 1.4 would be more ergonomic on iOS but is outside this shard and is not required for the AC to hold.' > "$w/$SLOT/$P"
join "$w"
[ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"$REFUSAL"*) exit 0 ;; esac
exit 1
