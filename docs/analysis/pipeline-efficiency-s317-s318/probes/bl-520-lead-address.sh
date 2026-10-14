#!/usr/bin/env bash
# BL-520 receipt probe: does every core instruction telling a teammate to message or escalate to
# the lead carry the address the harness registers (`to: "main"`, Rule 28)?
#
#   SUBJECT  process-rule-pins' lead-address arm, driven through its --lead-verdict entry over the
#            fixture's own corpus (lead_files: the install-scoped flat skill files, steps/,
#            rule-bodies/ and the roles), with the literal derived from Rule 28 as the fixture
#            derives it (`-`). The FLOOR IS PINNED HERE as a literal, never the fixture's
#            LEAD_FLOOR: a fixture whose floor was lowered alongside a site reworded out of the
#            predicate's reach would otherwise pass its own receipt.
#            -> exit 0 if the arm passes (fixed), 1 if it reports a bare site, a short floor or no
#            literal (live).
#   ABSENT   no --lead-verdict entry in the fixture (the arm was never built, or was removed): a
#            coarse line scan for the unaddressed instruction runs instead -> 1 when it finds one,
#            9 when it finds none, because a coarse zero cannot tell a fixed tree from a moved one.
#
# Floor 23 = the sites measured when the arm shipped (22 message/escalate/SendMessage items plus
# code-reviewer.md's "hand the review to the lead"). Raise it with the corpus; never lower it to
# pass. Measured at fe7d5ec2: no entry, 21 unaddressed lines -> probe exit 1. Run from the repo root.
set -u
F=core/fixtures/process-rule-pins/run.sh
FLOOR=23
[ -f "$F" ] && [ -d core/team-roles ] || exit 9
if grep -qF -- '"--lead-verdict"' "$F"; then
  bash "$F" --lead-verdict "$FLOOR" - >/dev/null 2>&1
  case $? in 0) exit 0 ;; 1) exit 1 ;; *) exit 9 ;; esac
fi
files="$(find core -type f -name '*.md' -not -path 'core/fixtures/*' -not -path 'core/skills/ai-dlc-update/*' | LC_ALL=C sort)"
[ -n "$files" ] || exit 9
# shellcheck disable=SC2086
n="$(grep -hiE 'message (the )?\**lead\**|escalate to the lead|`?SendMessage`?.*to the lead' $files | grep -vcF 'to: "main"')" || n=0
[ "$n" -gt 0 ] && exit 1
exit 9
