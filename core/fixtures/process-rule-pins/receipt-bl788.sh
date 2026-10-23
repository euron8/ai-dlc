#!/usr/bin/env bash
# Receipt: at `done` the closing writer copies each deferred AC's id AND predicate into the story
# file's `## Deferred ACs`, and deploy-validate §4b reads the predicate there and checks its literals
# against the deployed sha. Usage: receipt-bl788.sh [<root>]
# 0 = code-reviewer.md `## Ownership` (to the next `## ` heading) names the story file's
#     `## Deferred ACs`, a COPY of the predicate text, entries opening `- **<id>**`, `None.` and
#     `## Dev Agent Record`; qa.md's Deferred-AC discharge predicate item (to the next `- [ ]`) names
#     the story file's `## Deferred ACs` and a copy of the predicate; deploy-validate.md §4b (to the
#     next `### `) reads the predicate from the story file's `## Deferred ACs`, falls back to the QA
#     verdict, names a closing-writer defect, the deployed sha, `old -> new` and no silent substitution.
# 1 = a property is absent.
# 9 = no verdict: a subject file or its pre-existing anchor heading is absent.
# Each span is whitespace-collapsed, lowercased and HTML-comment stripped. "A copy of the predicate"
# is a copy verb within 80 characters before `predicate`, or `predicate` within 60 before one, with no
# period between, so an entry that only CITES the verdict holding the predicate does not satisfy it.
# Each negation is judged per sentence: a clause holds when one sentence carries it and that same
# sentence does not negate it, so a correct sentence elsewhere in the span cannot void it.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
CR="$ROOT/core/team-roles/code-reviewer.md"; QA="$ROOT/core/team-roles/qa.md"
DV="$ROOT/core/skills/ai-dlc/steps/deploy-validate.md"
QLEAD='- [ ] **Deferred-AC discharge predicate (HARD GATE).**'
for f in "$CR" "$QA" "$DV"; do [ -f "$f" ] || { echo "REFUSED: subject absent: $f" >&2; exit 9; }; done
n="$(grep -c '^## Ownership' "$CR")" || n=0
[ "$n" -ge 1 ] || { echo "REFUSED: no ## Ownership in $CR" >&2; exit 9; }
n="$(grep -cF -- "$QLEAD" "$QA")" || n=0
[ "$n" -ge 1 ] || { echo "REFUSED: no discharge-predicate item in $QA" >&2; exit 9; }
n="$(grep -c '^### 4b\.' "$DV")" || n=0
[ "$n" -ge 1 ] || { echo "REFUSED: no ### 4b. in $DV" >&2; exit 9; }

# span <file> <start prefix, matched after leading blanks> <end prefixes, space-free, | separated>
span() {
  SP_S="$2" SP_E="$3" awk '
  BEGIN { s = ENVIRON["SP_S"]; ne = split(ENVIRON["SP_E"], E, "|") }
  { line = $0
    if (com) { c = index(line, "-->"); if (!c) next; line = substr(line, c + 3); com = 0 }
    while ((c = index(line, "<!--")) > 0) {
      r = substr(line, c + 4); d = index(r, "-->")
      if (d) line = substr(line, 1, c - 1) substr(r, d + 3); else { line = substr(line, 1, c - 1); com = 1 }
    }
    t = line; sub(/^[ \t]+/, "", t)
    if (!on) { if (index(t, s) == 1) { on = 1; out = t }; next }
    for (i = 1; i <= ne; i++) if (index(t, E[i]) == 1) exit
    out = out " " t }
  END { gsub(/[[:space:]]+/, " ", out); print tolower(out) }' "$1"
}
COPY='(cop(y|ies|ied)[^.]{0,80}predicate|predicate[^.]{0,60}cop(y|ies|ied))'
NOCOPY='(not|never|no) (its |the |that ac.s )?predicate|predicate is not copied'
has()  { grep -qF -- "$2" <<<"$1"; }
# sents <span>: one sentence per line, split after a period followed by a blank (as receipt-bl787.sh
# does) and after a bold lead-in's closing `.**`; a line opening `**` is that lead-in, a title and not
# a rule body, so it is dropped and cannot carry a clause its body sentence negates.
sents() { printf '%s\n' "$1" | awk '{ gsub(/\. /, ".\n"); gsub(/\.\*\* /, ".**\n"); print }' | grep -vE '^\*\*[^*]*\.\*\*$'; }
# sat <span> <positive ERE> <negation ERE>: 0 when ONE sentence matches the positive ERE and that same
# sentence does not match the negation ERE, so a correct sentence elsewhere in the span that happens
# to carry a negation word does not void the clause.
sat() { local s m; s="$(sents "$1")" || return 1; m="$(grep -E -- "$2" <<<"$s")" || return 1
  m="$(grep -vE -- "$3" <<<"$m")" || return 1; [ -n "$m" ]; }
# A copy clause that negates the predicate (ids only) is no copy.
hasE() { sat "$1" "$2" "$NOCOPY"; }
rc=0
fail() { echo "FAIL: $1"; rc=1; }

c="$(span "$CR" '## Ownership' '## ')"
has "$c" 'story file' && has "$c" '`## deferred acs`' || fail "code-reviewer.md Ownership does not name the story file's ## Deferred ACs"
hasE "$c" "$COPY" || fail "code-reviewer.md Ownership does not copy the predicate text into the entry"
has "$c" '`- **<id>**`' || fail "code-reviewer.md Ownership does not open each entry with - **<id>**"
sat "$c" '`none\.`' '(never|not|no) (write )?`none\.`|gets no section' || fail "code-reviewer.md Ownership does not write None. for a story with no deferred AC, or negates it"
has "$c" '`## dev agent record`' || fail "code-reviewer.md Ownership does not place the section by ## Dev Agent Record"

q="$(span "$QA" "$QLEAD" '- [ ]|## ')"
has "$q" 'story file' && has "$q" '`## deferred acs`' || fail "qa.md discharge-predicate item does not name the story file's ## Deferred ACs"
hasE "$q" "$COPY" || fail "qa.md discharge-predicate item does not say the predicate is copied"

d="$(span "$DV" '### 4b.' '### |## ')"
has "$d" 'story file' && has "$d" '`## deferred acs`' || fail "deploy-validate.md 4b does not name the story file's ## Deferred ACs"
sat "$d" '(from|in) the story file' '(not|never) (from )?the story file' || fail "deploy-validate.md 4b does not read the predicate from the story file, or negates the read"
hasE "$d" '(fall ?back|fallback)[^.]{0,60}qa verdict|qa verdict[^.]{0,60}(fall ?back|fallback)' || fail "deploy-validate.md 4b has no QA-verdict fallback for a story with no section"
hasE "$d" 'closing.writer defect' || fail "deploy-validate.md 4b does not name a missing entry a closing-writer defect"
has "$d" 'deployed sha' || fail "deploy-validate.md 4b does not name the deployed sha"
sat "$d" 'check (each|every) literal' 'never (against )?the deployed sha|not against the deployed sha' || fail "deploy-validate.md 4b does not check literals against the deployed sha, or negates the check"
has "$d" '`old -> new`' || fail "deploy-validate.md 4b does not record a corrected literal as old -> new"
has "$d" 'never a silent substitution' || fail "deploy-validate.md 4b does not forbid a silent substitution"

[ "$rc" -eq 0 ] && echo "PASS: the closing writer copies each deferred predicate into the story file and 4b reads it there against the deployed sha"
exit "$rc"
