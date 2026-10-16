#!/usr/bin/env bash
# push-authorised.sh -- BL-574's receipt (and BL-562's prose half). A directed handoff authorises the
# handoff push, and the step text must say so BESIDE the prescribed command, or a lead invents an
# operator go-ahead before pushing (measured on graph: the operator had to overrule an invented one).
#
# Keyed on PROXIMITY, never on a whole-file grep: for each site, the sentence must sit within
# WINDOW lines of the line carrying the prescribed `git push -u origin HEAD`. A copy of the
# sentence elsewhere in the file satisfies nothing. Sites:
#   steps/handoff.md             step 3, the parenthesised `(\`git push -u origin HEAD\`)`
#   steps/_gate-procedures.md    auto-handoff step 3, the same parenthesised form (one occurrence)
#   steps/retro.md               6b, the fenced `git push -u origin HEAD` line
# The authorisation sentence is claimed at all three sites. The `--no-verify` prohibition is claimed
# at handoff.md and _gate-procedures.md ONLY: retro.md carries the authorisation sentence alone, so
# a prohibition claim there would fail on a site that never had one. It is keyed on the prohibition's
# FIRST physical line (the one opening `**Never \`--no-verify\`**`), within WINDOW lines of the push.
#
# Self-probe first, both directions, on mktemp trees: a sentence WINDOW+5 lines away is refused,
# and one adjacent is accepted; the same two for the prohibition line.
#
# Usage: push-authorised.sh      Exit: 0 every site carries what it owes, 1 a site lacks it, 2 broken.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SENT='A directed handoff authorises this push; the lead does not ask the operator for a go-ahead again.'
PROH='**Never `--no-verify`**: the pre-push hook runs on every pipeline push, whatever the change'
WINDOW=6

# near <file> <anchor-regex> [<text>] -> 0 when <text> (default SENT) occurs within WINDOW lines of
# a line matching anchor.
near() {
  awk -v s="${3:-$SENT}" -v a="$2" -v w="$WINDOW" '
    index($0, s) { S[++ns] = NR }
    $0 ~ a { A[++na] = NR }
    END { for (i = 1; i <= na; i++) for (j = 1; j <= ns; j++) { d = S[j] - A[i]; if (d < 0) d = -d; if (d <= w) exit 0 }
          exit 1 }' "$1"
}

P="$(mktemp -d "${TMPDIR:-/tmp}/push-auth.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
for pair in "SENT:$SENT" "PROH:$PROH"; do
  tag="${pair%%:*}"; txt="${pair#*:}"
  printf 'x\ngit push -u origin HEAD\n%s\n' "$txt" > "$P/$tag.near"
  { printf 'x\ngit push -u origin HEAD\n'; i=0; while [ "$i" -lt $((WINDOW + 5)) ]; do echo pad; i=$((i+1)); done; printf '%s\n' "$txt"; } > "$P/$tag.far"
  if ! near "$P/$tag.near" '^git push -u origin HEAD$' "$txt" || near "$P/$tag.far" '^git push -u origin HEAD$' "$txt"; then
    echo "FIXTURE BROKEN: the proximity probe did not discriminate for $tag (adjacent accepted, distant refused)" >&2; exit 2
  fi
done

pick() { for c in "$@"; do [ -f "$c" ] && { printf '%s\n' "$c"; return 0; }; done; return 1; }
STEPS="$(cd "$HERE/../../skills/ai-dlc/steps" 2>/dev/null && pwd)" \
  || STEPS="$(cd "$HERE/../../../.claude/skills/ai-dlc/steps" 2>/dev/null && pwd)" \
  || { echo "FIXTURE ERROR: steps/ not found in either layout" >&2; exit 2; }
fails=0
# row: <file>|<anchor regex>|<claims the prohibition: 1 or 0>
for row in 'handoff.md|\(`git push -u origin HEAD`\)|1' '_gate-procedures.md|\(`git push -u origin HEAD`\)|1' 'retro.md|^git push -u origin HEAD$|0'; do
  f="$STEPS/${row%%|*}"; rest="${row#*|}"; a="${rest%|*}"; claims="${rest##*|}"
  [ -f "$f" ] || { echo "FIXTURE ERROR: $f is absent" >&2; exit 2; }
  if ! grep -qE "$a" "$f"; then echo "FIXTURE ERROR: ${row%%|*} carries no prescribed push matching $a" >&2; exit 2; fi
  if near "$f" "$a"; then echo "  ok    ${row%%|*}: the authorisation sentence sits within $WINDOW lines of the push"
  else echo "  FAIL  ${row%%|*}: no authorisation sentence within $WINDOW lines of the prescribed push"; fails=$((fails+1)); fi
  if [ "$claims" = 1 ]; then
    if near "$f" "$a" "$PROH"; then echo "  ok    ${row%%|*}: the --no-verify prohibition sits within $WINDOW lines of the push"
    else echo "  FAIL  ${row%%|*}: no --no-verify prohibition within $WINDOW lines of the prescribed push"; fails=$((fails+1)); fi
  fi
done
[ "$fails" -eq 0 ] && { echo "push-authorised: PASS"; exit 0; }
echo "push-authorised: $fails site(s) FAILED"; exit 1
