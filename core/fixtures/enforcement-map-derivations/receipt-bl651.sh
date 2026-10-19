#!/bin/bash
# BL-651 receipt. usage: receipt-bl651.sh; run from the repo root.
#   exit 0   with the placeholder-key reader line of validate-mandatory-rules.sh deleted and a comment
#            spelling the sprint slot appended, I84 fires and names validate-mandatory-rules.sh
#            (the fix is present)
#   exit 1   it does not
#   exit 9   the receipt cannot measure: the tree could not be copied, or the seeded edit did not apply
set -uo pipefail
W="$(mktemp -d)" || exit 9
trap '[ -n "$W" ] && rm -rf "$W"' EXIT
# ONLY WHAT `--arms I84` READS, not the whole tree. Each path's reader, in validate-enforcement-map.sh:
#   the five startup inputs it refuses without (the GV/MAP/CORE_MANIFEST/SETUP_SITES/FIXTURE_MANIFEST loop);
#   scripts/ -- the validator itself and render-invariant-index.sh, which the `--arms` renderer call
#     runs on an explicit source, so no VERSION walk; and I84's corpus `find`: every core *.sh outside
#     core/fixtures/, plus all of scripts/ and .githooks/; core/schemas/sprint-status.json is
#     I84_SCHEMA. That find corpus is reproduced exactly, so I84 scans the same files as it does on
#     the full tree.
git archive HEAD -- 'core/*.sh' ':(exclude)core/fixtures' scripts .githooks \
  core/schemas/sprint-status.json core/skills/ai-dlc/steps/gate-validation.md \
  core/skills/ai-dlc/enforcement-map.yaml core/skills/ai-dlc/core-manifest.md \
  core/skills/ai-dlc-update/reconcile/setup-sites.md core/skills/ai-dlc-update/fixture-manifest.md | tar -x -C "$W" || exit 9
M="$W/core/scripts/validate-mandatory-rules.sh"
[ -f "$M" ] || exit 9
[ -f "$W/scripts/validate-enforcement-map.sh" ] || exit 9
before="$(grep -c 'stories_dir_sprint_placeholder' "$M")" || before=0
grep -v 'stories_dir_sprint_placeholder' "$M" > "$W/m.tmp"
cat "$W/m.tmp" > "$M"
printf '# composes s{sprint}\n' >> "$M"
after="$(grep -c 'stories_dir_sprint_placeholder' "$M")" || after=0
[ "$before" -gt 0 ] && [ "$after" -eq 0 ] || exit 9
out="$(cd "$W" && bash scripts/validate-enforcement-map.sh --arms I84 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || exit 1
case "$out" in *validate-mandatory-rules.sh*) exit 0 ;; esac
exit 1
