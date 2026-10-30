#!/usr/bin/env bash
# Receipt: Rule 11(a)'s unbadged trigger is a VALUE question, and Rule 12's sort subsection decides the
# design choices a source settles.
# Usage: receipt-bl876.sh [<root>]
# 0 = SKILL.md's Rule 11 span (its `### Rule 11 ` heading to the next `### `/`#### ` heading) carries the
#     value-trigger clause, and the `#### Operator decisions: sort before asking` subsection (to the next
#     heading) carries every sort clause; both spans have HTML comments stripped and whitespace collapsed.
#     The clause list is the r11a-value-trigger and r11a-sort-* pin keys in run.sh, byte for byte.
# 1 = a clause is absent, or the sort subsection is absent. The s321 shape is a Rule 11(a) that makes a
#     question unbadged whenever an option touches a config leaf, with no sort to decide sourced choices.
# 9 = no verdict: SKILL.md or its `### Rule 11 ` anchor absent.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
F="$ROOT/core/skills/ai-dlc/SKILL.md"
[ -f "$F" ] || { echo "REFUSED: subject absent: $F" >&2; exit 9; }
n="$(grep -c '^### Rule 11 ' "$F")" || n=0
[ "$n" -eq 1 ] || { echo "REFUSED: Rule 11 anchor count $n in $F" >&2; exit 9; }
span() {
  awk -v a="$1" '
    { line = $0
      if (com) { c = index(line, "-->"); if (!c) next; line = substr(line, c + 3); com = 0 }
      while ((c = index(line, "<!--")) > 0) {
        r = substr(line, c + 4); d = index(r, "-->")
        if (d) line = substr(line, 1, c - 1) substr(r, d + 3); else { line = substr(line, 1, c - 1); com = 1 }
      }
      if (!on) { if (index(line, a) == 1) on = 1; next }
      if (index(line, "### ") == 1 || index(line, "#### ") == 1) exit
      s = s " " line }
    END { gsub(/[[:space:]]+/, " ", s); print s }' "$F"
}
r11="$(span '### Rule 11 ')"
srt="$(span '#### Operator decisions: sort before asking')"
rc=0
need() { case "$1" in *"$2"*) : ;; *) echo "FAIL: $3 lacks: $2"; rc=1 ;; esac; }
need "$r11" 'decides a value the operator alone owns and no operator words fix' "Rule 11"
for c in \
  '**Sort every question three ways before it is asked.**' \
  'record it as a Rule 12 Tier 2 `DECIDED_AUTONOMOUSLY` entry naming its source and a one-line reason, add one veto line for it to the next `AskUserQuestion` you send' \
  "leaves every operator-owned value in force or sets it to the operator's verbatim value or that value exactly converted between units" \
  "Such a choice decides no value, so Rule 11(a)'s UNBADGED trigger does not reach it." \
  'A choice that otherwise sets, relaxes or widens a value, a limit or an authority is settled by no source' \
  'A design choice no source settles is asked with one option `(Recommended)`' \
  'The tree never settles a value' \
  'Outside this sort, each asked as its own rule says:' \
  'for WHERE and HOW only' \
  'words a lead wrote into a `LOCKED_REQUIREMENTS` entry are no source for what they add' \
  'the sprint-scope confirmation (`steps/route.md` Step 6)'; do
  need "$srt" "$c" "the sort subsection"
done
[ "$rc" -eq 0 ] && echo "PASS: the unbadged trigger is a value question and the sort subsection carries every clause"
exit "$rc"
