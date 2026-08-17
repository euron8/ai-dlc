#!/usr/bin/env bash
# gate-verdict-grep-shape — the mandated verdict grep must match the mandated review template.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `gate-validation.md` Check 1 forbids the lead from asserting a gate verdict and names a
# grep to source it from the review file instead. `code-reviewer.md` defines the template
# that writes those files. Nothing joined the two, and they disagreed about shape: the grep
# required `Verdict:` at column 0 while the template emits `## Verdict` with the value on
# the next line. Measured on the reference consumer: 14 of 1011 real review files matched.
#
# The lead therefore ran the mandated command, got nothing, and had no specified fallback —
# landing back on the recollection the paragraph exists to forbid. A grep that matches
# nothing reads exactly like a verdict that is absent.
#
# Both halves are load-bearing. A pattern that misses the template silently un-gates every
# review; a pattern loose enough to hit any prose mention of the word "verdict" sources the
# gate answer from a sentence. This fixture derives the pattern from the rule file and the
# heading from the role file, so a future edit to either that breaks the join fails here
# rather than on a consumer's gate months later.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

find_one() { # find_one <core-relative-path>
  local rel="$1"
  if [ -n "$ROOT" ] && [ -f "$ROOT/core/$rel" ]; then printf '%s' "$ROOT/core/$rel"
  elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/$rel" ]; then printf '%s' "$ROOT/.claude/$rel"
  fi
}

GATE="$(find_one skills/ai-dlc/steps/gate-validation.md)"
ROLE="$(find_one team-roles/code-reviewer.md)"
[ -n "$GATE" ] || { echo "FIXTURE ERROR: gate-validation.md not found in either layout" >&2; exit 2; }
[ -n "$ROLE" ] || { echo "FIXTURE ERROR: code-reviewer.md not found in either layout" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# --- Derive, never hardcode -------------------------------------------------
# The pattern is read out of the rule file's own `grep -inE '<pattern>'` directive. A
# hardcoded copy here would be a second definition, and the two would drift exactly as the
# grep and the template did.
PAT="$(sed -n "s/.*grep -inE '\(.*\)' <review-file>.*/\1/p" "$GATE" | head -1)"
[ -n "$PAT" ] || {
  echo "FIXTURE STALE: no \`grep -inE '<pattern>' <review-file>\` directive in gate-validation.md" >&2
  exit 2
}

# The heading is read out of the role file's review-document template.
HEADING="$(sed -n '/^## Review Document Template/,/^```$/p' "$ROLE" \
           | grep -iE '^#+[[:space:]]*verdict' | head -1)"
[ -n "$HEADING" ] || {
  echo "FIXTURE STALE: no verdict heading in code-reviewer.md's Review Document Template" >&2
  exit 2
}

matches() { grep -qiE "$1" <<<"$2"; }

# A SECOND SUBJECT IN THE SAME ROLE FILE, HOSTED HERE BECAUSE THIS FIXTURE ALREADY RESOLVES IT.
#
# `### Missing Pre-Deploy Field Verification` classifies a PRODUCER-side condition — a change
# that adds a field to an API query — and for the whole life of the rule it was the only one in
# its contiguous severity run carrying no `**Evidence required:**` clause. A reviewer who made
# the observation was told nothing about what to record, so the classification was
# unfalsifiable. Absent in 21 of 21 revisions in which the rule existed, through a prose sweep
# that deleted from this file's Mandatory Severity section without noticing the gap beside it.
#
# WHAT IS DELIBERATELY NOT ASSERTED. The same fix added a query-shape step to the procedure at
# `## Field Verification`, and NO arm here covers it. An arm was built and measured: keyed on
# the word "query" plus a closed list of send verbs, 3 of 5 legitimate rewordings that fully
# preserved the instruction came back red — the wording "request shape", "transmits" and
# "introduces" all defeat it. Widening the alternation is guessing the synonym space, which
# leaves a false-positive set that is an open class of legitimate English: neither empty nor
# enumerable, so it fails CLAUDE.md's precondition. That half is UNGUARDED and this fixture's
# green line must not be read as covering it.
#
# `**Evidence required:**` is different in kind — a literal structural convention the file uses
# verbatim at 5 sites, not a phrase chosen to match prose. It survived all 5 rewordings.
RULE_SEC() { LC_ALL=C awk '/^### Missing Pre-Deploy Field Verification/{g=1;next} g&&/^### /{exit} g' "$1"; }

[ -n "$(RULE_SEC "$ROLE")" ] || {
  echo "FIXTURE STALE: no \`### Missing Pre-Deploy Field Verification\` rule in code-reviewer.md." >&2
  echo "  Either the heading moved — re-point RULE_SEC — or the rule was RETIRED, in which case" >&2
  echo "  this assertion retires with it. A fixture that lost its subject is not a tree defect," >&2
  echo "  and the two must not print the same verdict." >&2
  exit 2
}

# --- Assertion 1: THE JOIN --------------------------------------------------
# The whole point. The pattern the gate mandates must match the heading the template emits.
if matches "$PAT" "$HEADING"; then
  ok "the mandated grep matches the mandated template heading ($HEADING)"
else
  bad "the mandated grep does NOT match '$HEADING' — the gate cannot read the verdict of any review file the template produces, and a zero-match reads as an absent verdict"
fi

# --- Assertion 2: the shapes real review files actually use ------------------
# Sampled from the reference consumer's corpus. Each was a live miss under the old pattern.
while IFS='|' read -r label line; do
  if matches "$PAT" "$line"; then
    ok "matches $label"
  else
    bad "does NOT match $label — a real review-file shape the gate cannot read: $line"
  fi
done <<'SHAPES'
bare heading|## Verdict
inline heading|## Verdict: APPROVED
uppercase inline|## VERDICT: APPROVED
qualified heading|## Overall Verdict
qa-qualified heading|## QA Verdict
bold field|**Verdict:** REJECT
bold list item|- **Verdict:** APPROVED
column-zero field|Verdict:
trailing whitespace|## Verdict
deeper heading|### Verdict: PASS
SHAPES

# --- Assertion 3: precision — prose must NOT source a gate answer ------------
# A pattern loose enough to match a sentence turns narrative into a verdict. These are real
# lines from the consumer's corpus that must stay unmatched.
while IFS='|' read -r label line; do
  if matches "$PAT" "$line"; then
    bad "WRONGLY matches $label — the gate would source its answer from prose: $line"
  else
    ok "ignores $label"
  fi
done <<'PROSE'
mid-sentence mention|nor gate-2's QA verdict cites the map
trailing-clause mention|that would not have changed my verdict — DEPLOY_SAFE
unrelated heading|## Test Coverage Assessment
table header|RESPONSE field? | Verdict |
prose with decision|the decision to defer for one sprint was recorded
PROSE

# --- Assertion 4: MUTANT — the fixture must fail on the historical defect ----
# The pattern that shipped, verbatim. If this fixture cannot tell it from the current one,
# it proves nothing: a green run would mean only that the assertions cannot fire.
OLD='^(Verdict|Decision):'
if matches "$OLD" "$HEADING"; then
  bad "MUTANT NOT DETECTED: the historical pattern '$OLD' matches '$HEADING', so assertion 1 cannot distinguish the defect from the fix"
else
  ok "the historical pattern '$OLD' fails on the template heading (assertion 1 can fire)"
fi

# --- Assertion 5: the second half of the fix ---------------------------------
# Widening the pattern alone leaves the hole open: an unmatched file still falls back to
# recollection, just less often. The rule must make a zero-match terminal.
if grep -qiE 'zero matches? +fails? this check' "$GATE"; then
  ok "a zero-match is declared a FAIL, not a fallback"
else
  bad "gate-validation.md no longer declares zero matches a FAIL — a review file the pattern misses silently returns to the lead's recollection, which is the defect the check exists to prevent"
fi

# --- Assertion 6: the producer-side severity rule states its evidence --------
if grep -qF '**Evidence required:**' <<<"$(RULE_SEC "$ROLE")"; then
  ok "the Missing Pre-Deploy Field Verification rule carries an \`**Evidence required:**\` clause"
  a6=present
else
  bad "\`### Missing Pre-Deploy Field Verification\` carries no \`**Evidence required:**\` clause — every other rule in its contiguous severity run does. Without one a reviewer who observes the trigger is told nothing about what to record, and the classification cannot be checked by anyone downstream"
  a6=absent
fi

# --- Assertion 7: MUTANT — assertion 6 must fail on the historical defect ----
# ASSERTION 6 OWNS THE ABSENT CASE and this arm stands down for it. A mutation that deletes a
# clause already missing changes no bytes, and reporting that as a broken mutant on top of the
# real finding prints two failures for one defect — which is how a battery starts looking
# entangled. Measured against the true pre-fix file at 941021d^, where both fired.
if [ "$a6" = absent ]; then
  ok "MUTANT stands down — assertion 6 already reports the clause absent, and it owns that case"
else
  # A COPY, never an in-place edit, guarded by `cmp -s` so a sed that matched nothing cannot
  # pass as a mutation. The clause is deleted as a range because it spans two lines; keying the
  # range end on `in the review doc.` is safe only because the search runs FORWARD from the
  # start line — an identical tail sits earlier in the file, at Evidence/Assertion Separation.
  MUT="$(mktemp)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  trap 'rm -f "$MUT"' EXIT
  cp "$ROLE" "$MUT"
  LC_ALL=C sed -i.bak '/^\*\*Evidence required:\*\* Include the query diff, the added field names, and$/,/^the deployed-schema source consulted, in the review doc\.$/d' "$MUT"
  rm -f "$MUT.bak"
  if cmp -s "$ROLE" "$MUT"; then
    bad "MUTANT changed no bytes — its sed matched nothing, so an unmutated copy would score as a kill and assertion 6 would be proving nothing"
  elif grep -qF '**Evidence required:**' <<<"$(RULE_SEC "$MUT")"; then
    bad "MUTANT NOT DETECTED: with the clause deleted, assertion 6 still reads it as present — the extraction is picking up an \`**Evidence required:**\` from a neighbouring rule, so a green assertion 6 means nothing"
  else
    ok "with the clause deleted from a copy, assertion 6 goes red (it can fire)"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "gate-verdict-grep-shape: PASS"; exit 0; fi
echo "gate-verdict-grep-shape: $fails assertion(s) FAILED" >&2
exit 1
