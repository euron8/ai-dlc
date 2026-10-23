#!/usr/bin/env bash
# Receipt: deploy-validate.md section 4's drift bullet makes a fix-forward owe its browser specs a run.
# Usage: receipt-bl789.sh [<root>]
# 0 = section 4 (its `### 4.` heading to the next `### ` heading, HTML comments stripped, whitespace
#     collapsed) says, in one place: the dev brief names the browser spec files, the dev's record carries
#     their run or why they could not run, the LEAD runs them against the redeployed instance when they
#     could not run, that run is recorded as `playwright` evidence, and a could-not-run record is not a pass.
# 1 = a clause is absent. The s319 shape is a section that stops at the dev's could-not-run record and
#     names no lead run against the redeployed instance.
# 9 = no verdict: deploy-validate.md absent or its `### 4.` anchor absent.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
F="$ROOT/core/skills/ai-dlc/steps/deploy-validate.md"
[ -f "$F" ] || { echo "REFUSED: subject absent: $F" >&2; exit 9; }
n="$(grep -c '^### 4\. ' "$F")" || n=0
[ "$n" -eq 1 ] || { echo "REFUSED: section 4 anchor count $n in $F" >&2; exit 9; }
sec="$(awk '
  { line = $0
    if (com) { c = index(line, "-->"); if (!c) next; line = substr(line, c + 3); com = 0 }
    while ((c = index(line, "<!--")) > 0) {
      r = substr(line, c + 4); d = index(r, "-->")
      if (d) line = substr(line, 1, c - 1) substr(r, d + 3); else { line = substr(line, 1, c - 1); com = 1 }
    }
    if (!on) { if (index(line, "### 4. ") == 1) on = 1; else next }
    else if (index(line, "### ") == 1) exit
    s = s " " line }
  END { gsub(/[[:space:]]+/, " ", s); print tolower(s) }' "$F")"
rc=0
need() { case "$sec" in *"$1"*) : ;; *) echo "FAIL: section 4 lacks: $2"; rc=1 ;; esac; }
need "brief names the browser spec" "the dev brief names the browser spec files"
need "why they could not run" "the dev records the run or why they could not run"
need "when they could not run, the lead runs them against the redeployed" "when they could not run, the lead runs the specs against the redeployed instance"
need "could-not-run record is not a pass" "a could-not-run record is not a pass"
need "\`playwright\` evidence" "that lead run is the playwright evidence"
[ "$rc" -eq 0 ] && echo "PASS: a fix-forward owes its browser specs a lead run when the dev could not run them"
exit "$rc"
