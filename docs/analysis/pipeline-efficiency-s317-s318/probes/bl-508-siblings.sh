#!/usr/bin/env bash
# BL-508 receipt probe: does the shipped join-remediator-shards.sh hold a sharded repair to the
# siblings contract -- a `repaired` entry with a real edit carries `- siblings:` -- without wedging
# a repair whose parts all predate the rule?
#
# Three worlds, each a files-mode join over ledger rows the REAL remediation-guard hook wrote:
#   PRE       one part, a repaired edit, no siblings: anywhere   -> must JOIN (the PENDING era)
#   TWIN      two parts, each carrying siblings:, plus a repaired `edit: n/a` entry with none
#                                                               -> must JOIN
#   OFFENDER  TWIN with part 02's siblings: removed            -> must REFUSE naming it
# exit 0 fixed, 1 live (any world answers the wrong way), 9 precondition missing.
# Measured at 0.781.0 (origin/main fe7d5ec2): OFFENDER joins -> exit 1. Run from the repo root.
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
entry() { # <story> <with siblings: yes|no>
  printf '### F-1 — MAJOR\n- disposition: repaired\n- edit: %s/stories/%s:1\n' "$SLOT" "$1"
  [ "$2" = yes ] && printf -- "- siblings:\n\n\`\`\`derived\n\$ grep -rn -F 'loads eagerly' %s/stories\n\$ grep -c -F 'loads on demand' %s/stories/%s\n1\n\`\`\`\n\n" "$SLOT" "$SLOT" "$1"
  printf -- '- derivation: n/a (no factual claim)\n- claim now asserted: the title reads loads on demand.\n\n'
  printf '### F-9 — MINOR\n- disposition: repaired\n- edit: n/a (wording only)\n- derivation: n/a (no factual claim)\n- claim now asserted: wording.\n'
}
join() { # <world> -> RC, OUT
  OUT="$(AI_DLC_PROJECT_ROOT="$1" bash "$J" --sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" \
    --since 2000-01-01T00:00:00Z --until 2999-12-31T23:59:59Z 2>&1)"; RC=$?
}
D=shards/stories-repair-p1
w="$(world)"; entry a.md no > "$w/$SLOT/$D/01.md"; entry b.md no > "$w/$SLOT/$D/02.md"
rm -f "$w/$SLOT/$D/02.md"; printf '### F-2 — MAJOR\n- disposition: repaired\n- edit: %s/stories/b.md:1\n- derivation: n/a (no factual claim)\n' "$SLOT" > "$w/$SLOT/$D/02.md"
join "$w"; [ "$RC" -eq 0 ] || exit 1
w="$(world)"; entry a.md yes > "$w/$SLOT/$D/01.md"; entry b.md yes > "$w/$SLOT/$D/02.md"
join "$w"; [ "$RC" -eq 0 ] || exit 1
w="$(world)"; entry a.md yes > "$w/$SLOT/$D/01.md"; entry b.md no > "$w/$SLOT/$D/02.md"
join "$w"
[ "$RC" -eq 2 ] || exit 1
case "$OUT" in *"02.md: the F-1 — MAJOR entry is repaired with an edit and carries no 'siblings:' field"*) exit 0 ;; esac
exit 1
