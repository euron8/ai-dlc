#!/bin/bash
# BL-696 receipt. usage: receipt-bl696.sh; run from the repo root.
#   exit 0   the shipping validator's I106 reports a ship-set filter that skips every candidate
#            (the `.dist-only` test line replaced by a bare `continue`, in a copy) by naming its
#            ship-set filter probe, while the unmutated copy is clean (the fix is present)
#   exit 1   the mutated copy is not reported: the filter has no probe, which is the defect
#   exit 9   the receipt cannot measure: the tree could not be copied, the line was not found
#            exactly once, or the unmutated control copy is not clean
set -uo pipefail
W="$(mktemp -d)" || exit 9
trap '[ -n "$W" ] && rm -rf "$W"' EXIT
git archive HEAD -- scripts .githooks core/schemas/sprint-status.json \
  core/skills/ai-dlc/steps/gate-validation.md core/skills/ai-dlc/enforcement-map.yaml \
  core/skills/ai-dlc/core-manifest.md core/skills/ai-dlc-update/reconcile/setup-sites.md \
  core/skills/ai-dlc-update/fixture-manifest.md | tar -x -C "$W" || exit 9
V="$W/scripts/validate-enforcement-map.sh"
[ -f "$V" ] || exit 9
# The corpus is one empty shipping fixture, so the derived ship set is non-empty and the corpus scan is clean.
mkdir -p "$W/core/fixtures/ctl" || exit 9
printf 'x\n' > "$W/core/fixtures/ctl/run.sh"
# Control: the unmutated copy must be clean on I106, or the mutant's failure proves nothing.
ctl="$(cd "$W" && bash scripts/validate-enforcement-map.sh --arms I106 2>&1)"; crc=$?
[ "$crc" -eq 0 ] || exit 9
# Mutant: the filter skips every candidate.
n="$(grep -cxF '    [ -f "$_fd/.dist-only" ] && continue' "$V")" || n=0
[ "$n" -eq 1 ] || exit 9
awk '$0 == "    [ -f \"$_fd/.dist-only\" ] && continue" { print "    continue"; next } { print }' "$V" > "$W/v.tmp" || exit 9
cat "$W/v.tmp" > "$V"
[ "$(grep -cxF '    [ -f "$_fd/.dist-only" ] && continue' "$V")" -eq 0 ] || exit 9
out="$(cd "$W" && bash scripts/validate-enforcement-map.sh --arms I106 2>&1)"; rc=$?
[ "$rc" -ne 0 ] || exit 1
case "$out" in *"ship-set filter probe"*) exit 0 ;; esac
exit 1
