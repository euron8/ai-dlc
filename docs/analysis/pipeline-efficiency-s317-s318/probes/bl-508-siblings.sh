#!/usr/bin/env bash
# BL-508 receipt probe: does the shipped join-remediator-shards.sh hold every repair to the siblings
# contract -- a `repaired` entry with a real edit carries `- siblings:` -- including a part set that
# omits it EVERYWHERE, while a --sources record written across a pull binds only from its first
# carrier?
#
# Parts-mode worlds, each a files-mode join over ledger rows the REAL remediation-guard hook wrote:
#   TOTAL     two parts, a repaired edit each, no siblings: anywhere   -> must REFUSE (the era is
#             the install, not the parts; no PENDING line)
#   TWIN      two parts, each carrying siblings: (a fence over its OWN story), plus a repaired
#             `edit: n/a` MINOR whose claim says a clause is "not required"  -> must JOIN
#   OFFENDER  TWIN with part 02's siblings: removed                      -> must REFUSE naming it
#   SETASIDE  one part, a repaired MAJOR carrying siblings:, set aside only as "outside this shard"
#                                                                        -> must REFUSE
# --sources worlds (a record no join wrote; one seat file F-1..F-3 under party-mode/s305):
#   SRC-ERA   pre-rule entry, a carrier, an entry omitting the field   -> rc 2 naming the third only
#   SRC-ESC   a pre-rule repaired edit and one escalated entry          -> rc 0, one PENDING line,
#                                                                         `ESCALATED-COUNT: 1`
# exit 0 fixed, 1 live (any world answers the wrong way), 9 precondition missing.
# Measured at 0.781.0 (origin/main fe7d5ec2): TOTAL and OFFENDER join -> exit 1. Run from the repo root.
set -u
J="$(pwd)/core/scripts/join-remediator-shards.sh"; H="$(pwd)/core/hooks/ai-dlc-gate-remediation-guard.sh"
[ -f "$J" ] && [ -f "$H" ] || exit 9
command -v jq >/dev/null 2>&1 || exit 9
SLOT=_bmad-output/planning-artifacts/s305
world() { # -> a project root with stories a.md and b.md, each edited by its own dispatched agent
  local w; w="$(mktemp -d)" || exit 9
  mkdir -p "$w/$SLOT/stories" "$w/$SLOT/shards/stories-repair-p1" "$w/_bmad-output/gate-adjudication" || exit 9
  printf '# Pipeline Snapshot\n' > "$w/_bmad-output/pipeline-snapshot.md"
  printf 'loads on demand\n' > "$w/$SLOT/stories/a.md"; printf 'loads on demand\n' > "$w/$SLOT/stories/b.md"
  for p in a:a16fddf14ea289491 b:acd81ddfb7c535037; do
    jq -nc --arg f "$w/$SLOT/stories/${p%%:*}.md" --arg a "${p#*:}" \
      '{session_id:"t", tool_name:"Edit", transcript_path:"", tool_input:{file_path:$f}, agent_id:$a}' \
      | CLAUDE_PROJECT_DIR="$w" bash "$H" >/dev/null 2>&1
  done
  [ -f "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl" ] || exit 9
  printf '%s' "$w"
}
entry() { # <story> <with siblings: yes|no> [claim tail]
  printf '### F-1 — MAJOR\n- disposition: repaired\n- edit: %s/stories/%s:1\n' "$SLOT" "$1"
  [ "$2" = yes ] && printf -- "- siblings:\n\n\`\`\`derived\n\$ grep -rn -F 'loads eagerly' %s/stories/%s\n\$ grep -c -F 'loads on demand' %s/stories/%s\n1\n\`\`\`\n\n" "$SLOT" "$1" "$SLOT" "$1"
  printf -- '- derivation: n/a (no factual claim)\n- claim now asserted: the title reads loads on demand.%s\n\n' "${3:-}"
  printf '### F-9 — MINOR\n- disposition: repaired\n- edit: n/a (wording only)\n- derivation: n/a (no factual claim)\n- claim now asserted: wording; the trailing clause the finding proposed is not required.\n'
}
join() { # <world> -> RC, OUT
  OUT="$(AI_DLC_PROJECT_ROOT="$1" bash "$J" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z 2>&1)"; RC=$?
}
src() { # <body> -> RC, OUT: --sources over a record beside one seat file carrying F-1..F-3
  local w; w="$(mktemp -d)" || exit 9
  mkdir -p "$w/.claude" "$w/_bmad-output/party-mode/s305" || exit 9
  printf '# seat\n\n## F-1 (major) sections: 1\n\n## F-2 (major) sections: 1\n\n## F-3 (major) sections: 1\n' \
    > "$w/_bmad-output/party-mode/s305/architecture-dev-1.md"
  printf '%b' "$1" > "$w/rec.md"
  OUT="$(AI_DLC_PROJECT_ROOT="$w" bash "$J" --sources "$w/rec.md" --sprint 305 2>&1)"; RC=$?
}
D=shards/stories-repair-p1
NOSIB="entry is repaired with an edit and carries no 'siblings:' field"
# TOTAL
w="$(world)"; entry a.md no > "$w/$SLOT/$D/01.md"; entry b.md no > "$w/$SLOT/$D/02.md"
join "$w"; [ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"01.md: the F-1 — MAJOR $NOSIB"*"02.md: the F-1 — MAJOR $NOSIB"*) ;; *) exit 1 ;; esac
case "$OUT" in *PENDING*) exit 1 ;; esac
# TWIN
w="$(world)"; entry a.md yes > "$w/$SLOT/$D/01.md"; entry b.md yes > "$w/$SLOT/$D/02.md"
join "$w"; [ "$RC" -eq 0 ] || exit 1
# OFFENDER
w="$(world)"; entry a.md yes > "$w/$SLOT/$D/01.md"; entry b.md no > "$w/$SLOT/$D/02.md"
join "$w"; [ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"02.md: the F-1 — MAJOR $NOSIB"*) ;; *) exit 1 ;; esac
# SETASIDE
w="$(world)"; entry a.md yes ' The dashboard display in Story 1.4 is outside this shard.' > "$w/$SLOT/$D/01.md"
entry b.md yes > "$w/$SLOT/$D/02.md"
join "$w"; [ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"01.md:1: the F-1 — MAJOR entry is dispositioned repaired while its claim sets part of the fix aside"*) ;; *) exit 1 ;; esac
# SRC-ERA
src '### F-1 — MAJOR\n- source: architecture-dev-1.md#F-1\n- disposition: repaired\n- edit: s305/stories/a.md:3\n\n### F-2 — MAJOR\n- source: architecture-dev-1.md#F-2\n- disposition: repaired\n- edit: s305/stories/a.md:9\n- siblings: n/a (insertion)\n\n### F-3 — MAJOR\n- source: architecture-dev-1.md#F-3\n- disposition: repaired\n- edit: s305/stories/a.md:12\n'
[ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"rec.md: the F-3 — MAJOR $NOSIB"*) ;; *) exit 1 ;; esac
case "$OUT" in *"the F-1 — MAJOR $NOSIB"*) exit 1 ;; esac
# SRC-ESC
src '### F-1 — MAJOR\n- source: architecture-dev-1.md#F-1\n- disposition: repaired\n- edit: s305/stories/a.md:3\n\n### F-2 — MAJOR\n- source: architecture-dev-1.md#F-2\n- disposition: escalated\n- edit: n/a\n'
[ "$RC" -eq 0 ] || exit 1
case "$OUT" in *"PENDING: 1 repaired edit(s)"*"ESCALATED: rec.md F-2 — MAJOR"*"ESCALATED-COUNT: 1 "*) exit 0 ;; esac
exit 1
