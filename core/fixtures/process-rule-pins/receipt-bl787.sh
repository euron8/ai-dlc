#!/usr/bin/env bash
# Receipt: qa.md's Deferred-AC discharge predicate gate requires a predicate keyed on a literal THIS
# repository writes to carry a sha-pinned `derived` fence citing the producing line, and REJECTs a
# literal written nowhere at that sha unless an external source is named. Usage: receipt-bl787.sh [<root>]
# 0 = inside the item (its `- [ ] **Deferred-AC discharge predicate` line to the next `- [ ]` line,
#     HTML comments stripped, whitespace collapsed, lowercased):
#     (a) one sentence names a `derived` fence, a `git grep`, a sha, and scopes itself to a literal
#         this repository writes -- so widening the rule to every literal fails;
#     (b) one sentence says the literal written nowhere (or by no component) IS REJECT, and no
#         negated form (`not a reject`) -- so a softened or negated verdict fails; and
#     (c) the item names the enumerated external-source escape, `names its external source (a
#         third-party api ...` -- so an escape widened to any source or to QA judgment fails.
# 1 = any of the three is absent.
# 9 = no verdict: qa.md absent, or its Deferred-AC item anchor absent.
# Sentences are judged, never one exact phrase, so a correct rewording still passes.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
QA="$ROOT/core/team-roles/qa.md"
[ -f "$QA" ] || { echo "REFUSED: subject absent: $QA" >&2; exit 9; }
n="$(grep -c '^- \[ \] \*\*Deferred-AC discharge predicate' "$QA")" || n=0
[ "$n" -ge 1 ] || { echo "REFUSED: no Deferred-AC discharge predicate item in $QA" >&2; exit 9; }
span="$(awk '
  { line = $0
    if (com) { c = index(line, "-->"); if (!c) next; line = substr(line, c + 3); com = 0 }
    while ((c = index(line, "<!--")) > 0) {
      r = substr(line, c + 4); d = index(r, "-->")
      if (d) line = substr(line, 1, c - 1) substr(r, d + 3); else { line = substr(line, 1, c - 1); com = 1 }
    }
    if (!on) { if (index(line, "- [ ] **Deferred-AC discharge predicate") == 1) { on = 1; span = line }; next }
    if (index(line, "- [ ]") == 1 || line ~ /^#/) exit
    span = span " " line }
  END { gsub(/[[:space:]]+/, " ", span); print tolower(span) }' "$QA")"
# One sentence per line: split after a period followed by a blank.
sents="$(printf '%s\n' "$span" | awk '{ gsub(/\. /, ".\n"); print }')"
rc=0
fence="$(grep -F -- '`derived` fence' <<<"$sents" | grep -F 'git grep' | grep -F 'sha' | grep -E 'this repository writes|written by this repository|this repository produces')" || fence=""
[ -n "$fence" ] || { echo "FAIL: no sentence requires a sha-pinned \`derived\` fence (git grep) for a literal this repository writes"; rc=1; }
rej="$(grep -E '(is|are) reject' <<<"$sents" | grep -vE '(not|never|no) (a )?reject' | grep -E 'nowhere|no component|no producer')" || rej=""
[ -n "$rej" ] || { echo "FAIL: no sentence makes a literal written nowhere at the sha a REJECT"; rc=1; }
case "$span" in *"names its external source (a third-party api"*) : ;; *) echo "FAIL: the item does not name the external-source escape"; rc=1 ;; esac
[ "$rc" -eq 0 ] && echo "PASS: the Deferred-AC gate pins a predicate's literal to its producing line and REJECTs an unwritten one"
exit "$rc"
