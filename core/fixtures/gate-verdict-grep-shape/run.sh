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

matches() { printf '%s\n' "$2" | grep -qiE "$1"; }

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

echo
if [ "$fails" -eq 0 ]; then echo "gate-verdict-grep-shape: PASS"; exit 0; fi
echo "gate-verdict-grep-shape: $fails assertion(s) FAILED" >&2
exit 1
