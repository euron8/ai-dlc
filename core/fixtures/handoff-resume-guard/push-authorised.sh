#!/usr/bin/env bash
# push-authorised.sh -- BL-574's receipt. A directed handoff authorises the handoff push, and the
# step text must say so BESIDE the prescribed command, or a lead invents an operator go-ahead
# before pushing (measured on graph: the operator had to overrule an invented one).
#
# Keyed on PROXIMITY, never on a whole-file grep: for each site, the sentence must sit within
# WINDOW lines of the line carrying the prescribed `git push -u origin HEAD`. A copy of the
# sentence elsewhere in the file satisfies nothing. Sites:
#   steps/handoff.md  step 3, the parenthesised `(\`git push -u origin HEAD\`)`
#   steps/retro.md    6b, the fenced `git push -u origin HEAD` line
# NOT a site: steps/_gate-procedures.md's auto-handoff twin (frozen this batch; owed).
#
# Self-probe first, both directions, on mktemp trees: a sentence WINDOW+5 lines away is refused,
# and one adjacent is accepted.
#
# Usage: push-authorised.sh      Exit: 0 both sites carry it, 1 a site lacks it, 2 broken.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SENT='A directed handoff authorises this push; the lead does not ask the operator for a go-ahead again.'
WINDOW=6

# near <file> <anchor-regex> -> 0 when SENT occurs within WINDOW lines of a line matching anchor.
near() {
  awk -v s="$SENT" -v a="$2" -v w="$WINDOW" '
    index($0, s) { S[++ns] = NR }
    $0 ~ a { A[++na] = NR }
    END { for (i = 1; i <= na; i++) for (j = 1; j <= ns; j++) { d = S[j] - A[i]; if (d < 0) d = -d; if (d <= w) exit 0 }
          exit 1 }' "$1"
}

P="$(mktemp -d "${TMPDIR:-/tmp}/push-auth.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
printf 'x\ngit push -u origin HEAD\n%s\n' "$SENT" > "$P/near"
{ printf 'x\ngit push -u origin HEAD\n'; i=0; while [ "$i" -lt $((WINDOW + 5)) ]; do echo pad; i=$((i+1)); done; printf '%s\n' "$SENT"; } > "$P/far"
if ! near "$P/near" '^git push -u origin HEAD$' || near "$P/far" '^git push -u origin HEAD$'; then
  echo "FIXTURE BROKEN: the proximity probe did not discriminate (adjacent accepted, distant refused)" >&2; exit 2
fi

pick() { for c in "$@"; do [ -f "$c" ] && { printf '%s\n' "$c"; return 0; }; done; return 1; }
STEPS="$(cd "$HERE/../../skills/ai-dlc/steps" 2>/dev/null && pwd)" \
  || STEPS="$(cd "$HERE/../../../.claude/skills/ai-dlc/steps" 2>/dev/null && pwd)" \
  || { echo "FIXTURE ERROR: steps/ not found in either layout" >&2; exit 2; }
fails=0
for row in 'handoff.md|\(`git push -u origin HEAD`\)' 'retro.md|^git push -u origin HEAD$'; do
  f="$STEPS/${row%%|*}"; a="${row#*|}"
  [ -f "$f" ] || { echo "FIXTURE ERROR: $f is absent" >&2; exit 2; }
  if ! grep -qE "$a" "$f"; then echo "FIXTURE ERROR: ${row%%|*} carries no prescribed push matching $a" >&2; exit 2; fi
  if near "$f" "$a"; then echo "  ok    ${row%%|*}: the authorisation sentence sits within $WINDOW lines of the push"
  else echo "  FAIL  ${row%%|*}: no authorisation sentence within $WINDOW lines of the prescribed push"; fails=$((fails+1)); fi
done
[ "$fails" -eq 0 ] && { echo "push-authorised: PASS"; exit 0; }
echo "push-authorised: $fails site(s) FAILED"; exit 1
