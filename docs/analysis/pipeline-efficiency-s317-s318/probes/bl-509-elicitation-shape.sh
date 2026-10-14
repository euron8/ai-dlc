#!/usr/bin/env bash
# BL-509 receipt probe: does the validation cycle prescribe elicitation's shape for EVERY subject
# type, and does stories-test-strategy.md step 4 name elicitation among its sharded passes?
#
# It drives the pin fixture's own corpus verdict rather than grepping the prose, so a sentence
# moved out of its section, fenced, commented or negated fails here exactly as it fails the gate.
#
#   PRECONDITION  the pin fixture exists (exit 9 otherwise)
#   ROWS          the seven pin rows exist in its table -> otherwise exit 1 (live: nothing pins it)
#   VERDICT       `run.sh --report` prints `ok` for each of the seven rows -> exit 0 (fixed), else 1
#
# Measured at 0.781.0 (origin/main fe7d5ec2): the rows are absent -> probe exit 1. Run from the
# repo root.
set -u
F=core/fixtures/process-rule-pins/run.sh
[ -f "$F" ] || exit 9
ROWS="elic-shape-files elic-shape-ordinals elic-shape-onefile elic-shape-sections elic-shape-expectsha elic-shape-lead sts-elic-sharded"
for r in $ROWS; do
  grep -q "^$r|" "$F" || exit 1
done
rep="$(bash "$F" --report 2>&1)"
for r in $ROWS; do
  case "$rep" in
    *"  ok    $r: pinned inside"*) ;;
    *) exit 1 ;;
  esac
done
exit 0
