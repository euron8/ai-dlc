#!/bin/bash
# BL-696 receipt. usage: receipt-bl696.sh; run from the repo root.
# Drives the shipping validator's I106 on three fresh copies: a control and two mutants of the ship-set filter.
#   control  the unmutated copy must be clean on I106, or neither mutant proves anything
#   mutant S the `.dist-only` test line replaced by a bare `continue`: the filter skips EVERY candidate, so a
#            SHIPPING fixture is never reported. It must exit nonzero AND name the probe's NOT-reported err
#   mutant D the `.dist-only` test line deleted: nothing is skipped, so a .dist-only fixture is admitted.
#            It must exit nonzero AND name the probe's "WAS reported for a .dist-only" err
#   exit 0   both mutants are killed, each by its OWN err text (the fix is present)
#   exit 1   either mutant survives, or is killed only by the other direction's text
#   exit 9   the receipt cannot measure: a copy failed, the line was not found exactly once, or the control is not clean
set -uo pipefail
W="$(mktemp -d)" || exit 9
trap '[ -n "$W" ] && rm -rf "$W"' EXIT
LINE='    [ -f "$_fd/.dist-only" ] && continue'
PHRASE_S='ship-set filter probe (a SHIPPING fixture with a nested walk-up file) was NOT reported'
PHRASE_D='ship-set filter probe WAS reported for a .dist-only fixture'

# mkcopy <name>: a fresh copy holding what `--arms I106` reads, plus one empty shipping fixture so the
# derived ship set is non-empty and the corpus scan is clean.
mkcopy() {
  mkdir -p "$W/$1" || return 1
  git archive HEAD -- scripts .githooks core/schemas/sprint-status.json \
    core/skills/ai-dlc/steps/gate-validation.md core/skills/ai-dlc/enforcement-map.yaml \
    core/skills/ai-dlc/core-manifest.md core/skills/ai-dlc-update/reconcile/setup-sites.md \
    core/skills/ai-dlc-update/fixture-manifest.md | tar -x -C "$W/$1" || return 1
  [ -f "$W/$1/scripts/validate-enforcement-map.sh" ] || return 1
  mkdir -p "$W/$1/core/fixtures/ctl" || return 1
  printf 'x\n' > "$W/$1/core/fixtures/ctl/run.sh"
}
# mutate <name> <replacement-or-empty> <mode>: replace the filter line (mode r) or delete it (mode d)
mutate() {
  V="$W/$1/scripts/validate-enforcement-map.sh"
  n="$(grep -cxF "$LINE" "$V")" || n=0
  [ "$n" -eq 1 ] || return 1
  if [ "$2" = r ]; then
    awk -v L="$LINE" '$0 == L { print "    continue"; next } { print }' "$V" > "$W/$1.tmp" || return 1
  else
    awk -v L="$LINE" '$0 == L { next } { print }' "$V" > "$W/$1.tmp" || return 1
  fi
  cat "$W/$1.tmp" > "$V"
  [ "$(grep -cxF "$LINE" "$V")" -eq 0 ] || return 1
}
# run <name>: I106 on that copy; sets out and rc
run() { out="$(cd "$W/$1" && bash scripts/validate-enforcement-map.sh --arms I106 2>&1)"; rc=$?; }

mkcopy ctl || exit 9
run ctl; [ "$rc" -eq 0 ] || exit 9

mkcopy S || exit 9
mutate S r || exit 9
run S
[ "$rc" -ne 0 ] || exit 1
case "$out" in *"$PHRASE_S"*) ;; *) exit 1 ;; esac

mkcopy D || exit 9
mutate D d || exit 9
run D
[ "$rc" -ne 0 ] || exit 1
case "$out" in *"$PHRASE_D"*) ;; *) exit 1 ;; esac
exit 0
