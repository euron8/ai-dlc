#!/usr/bin/env bash
# askuserquestion-citation/run.sh — prove --cite accepts an AskUserQuestion answer, that it
# accepts ONLY the answer, and that Check B was not widened along with it.
#
# THE DEFECT. genuineOperatorText returns "" for any user record carrying a tool_result. An
# AskUserQuestion answer IS that shape, so --cite structurally could not accept any
# AskUserQuestion-sourced operator decision — a closed class, not one bad citation. Rule 11(a)
# names AskUserQuestion as the sanctioned mechanism for exactly this decision, so citing a
# genuine, deliberate, timestamped operator selection failed with the identical message the
# S290 FABRICATION case produced. The mirror image of the failure Check 2a exists to catch.
#
# THE HAZARD THE FIX MUST NOT CREATE. The tool_result text carries the QUESTIONS as well as
# the answers, and the questions are text the LEAD authored. A fix that accepted the whole
# string would let a lead cite its own words and pass the provenance check — reintroducing
# S290 through the repair of its mirror image. Assertion 2 is the one that guards that.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
# Capture, never pipe. --cite exits 2 on NOMATCH, and under `set -o pipefail` a
# `cite ... | grep -q NOMATCH` pipeline inherits that 2 even when grep matched — so every
# assertion expecting NOMATCH would take its else branch and report a failure that did not
# happen. Caught by this fixture on its first run.
cite() { bash "$VALIDATOR" --transcript "$1" --cite "$2" 2>/dev/null || true; }

echo "askuserquestion-citation:"

# --- Assertion 1: THE FIX — an AskUserQuestion ANSWER is citable --------------
R="$(cite "$ASK" "$ANSWER")"
case "$R" in
  MATCH*) ok "an AskUserQuestion answer cites as a genuine operator message" ;;
  *)      bad "the operator's AskUserQuestion answer still cannot be cited ($R) — Check 2a rejects the pipeline's own sanctioned mechanism" ;;
esac

# --- Assertion 2: THE HAZARD — the LEAD-AUTHORED QUESTION is NOT citable ------
# Same record, same string. If this matches, a lead can author a question, have the operator
# pick any option at all, and then cite its own question text as operator authorization.
R="$(cite "$ASK" "$QUESTION")"
case "$R" in
  NOMATCH*) ok "the lead-authored QUESTION in the same tool_result is NOT citable — only the answer side is read" ;;
  *)        bad "FABRICATION VECTOR OPEN ($R): the lead's own question text cited as operator authorization. This is S290 reintroduced through the fix for its mirror image." ;;
esac

# --- Assertion 3: a non-AskUserQuestion tool_result stays rejected -------------
# Its bytes are an answer block verbatim. Only the PAIRED tool_use distinguishes it.
R="$(cite "$OTHER" "$ANSWER")"
case "$R" in
  NOMATCH*) ok "an identical string in a Bash tool_result is rejected — the pairing decides, not the bytes" ;;
  *)        bad "any tool_result that LOOKS like an answer block is now citable ($R) — the predicate is sniffing text instead of resolving the tool_use" ;;
esac

# --- Assertion 4: REGRESSION — a freely-typed message still cites --------------
R="$(cite "$TYPED" "$ANSWER")"
case "$R" in
  MATCH*) ok "a freely-typed operator message still cites (the original path is intact)" ;;
  *)      bad "the split broke plain typed-message citation ($R) — the regression this change must not cause" ;;
esac

# --- Assertion 5: Check B was NOT widened -------------------------------------
# The lead SOLICITED the answer, then advanced. No pause flag is set, because a tool result is
# not a UserPromptSubmit, and no acknowledgement is owed. If AskUserQuestion answers entered
# Check B, every checkpoint in every sprint would score as a steamroll.
COUNT="$(bash "$VALIDATOR" --transcript "$ASK" --count 2>/dev/null)"
if [ "$COUNT" = "0" ]; then
  ok "Check B counts 0 on AskUserQuestion -> advance (the predicate was split, not widened)"
else
  bad "Check B counted $COUNT on an AskUserQuestion the lead itself solicited — every operator checkpoint now reads as a steamroll"
fi

# --- Assertion 6: MUTANT — answer-side extraction is what makes 2 hold ---------
# Widen the extraction to the whole tool_result string, exactly as a naive fix would, and the
# lead-authored question MUST become citable. If it does not, assertion 2 is passing for some
# other reason and proves nothing about the extraction.
MUT="$WORK/validator-mutant.sh"
sed 's|for (const m of raw.matchAll(/"\\s\*=\\s\*"(\[^"\]\*)"/g)) out.push(m\[1\]);|out.push(raw);|' \
  "$VALIDATOR" > "$MUT"
if ! grep -q 'out.push(raw);' "$MUT"; then
  bad "FIXTURE STALE: could not build the whole-string mutant — askUserQuestionAnswers' extraction line was reworded"
else
  R="$(bash "$MUT" --transcript "$ASK" --cite "$QUESTION" 2>/dev/null || true)"
  case "$R" in
    MATCH*) ok "mutant: accepting the whole tool_result makes the lead's own question citable — assertion 2 has teeth" ;;
    *)      bad "MUTANT DID NOT FAIL ($R) — the question is uncitable even when the whole string is accepted, so assertion 2 is not testing the extraction" ;;
  esac
fi

echo
if [ "$fails" -eq 0 ]; then echo "askuserquestion-citation: PASS"; exit 0; fi
echo "askuserquestion-citation: $fails assertion(s) FAILED" >&2
exit 1
