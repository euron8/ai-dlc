#!/usr/bin/env bash
# blocker-adjudication-record — a decision the pull takes must be evidenced, and it must have a
# durable home that the delivered PR shows the operator.
#
# Usage: run.sh
# Exit:  0 = every assertion holds (or SKIP on a consumer whose installed subject predates the
#        decisions record), 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# ONE — a decision had nowhere durable to go. The report is a fixed filename the NEXT DRY RUN
# OVERWRITES, and the reconcile log is not written until the apply. A decision recorded in either
# is a decision lost. The home is `_bmad-output/ai-dlc-update/pull-decisions.tsv`: the driver
# (`reconcile/pull.sh`) appends its rows there, the model appends its own, and `pull.sh pr-body`
# renders the file into the update PR body, so the operator's merge is the approval of what is in
# it. This fixture keys that half on the DRIVER's emission sites (the path assignment and the PR-body
# renderer's read of it), never on prose alone.
#
# TWO — the decision needed no evidence. Step 8's defect drain requires a cited command and its
# decisive output line for every filing. A decision row must carry the same, because some decisions
# (a retirement, a revert) delete consumer-owned text. The step-8 rule is the ANCHOR, not a copy:
# this fixture reads the citation requirement out of the drain bullet and requires the decision
# rule to carry one too, so the two cannot drift apart.
#
# THE SUBJECT CAN LAG THIS FIXTURE ON A CONSUMER. A core fixture lands one pull ahead of the
# skill it guards. An installed SKILL.md that still names the retired per-pull adjudication file
# (`blocker-adjudication-<ts>.md`), or a consumer with no installed `reconcile/pull.sh`, is that
# state: SKIP, never a pass and never a failure. In the distribution the subject is always
# present, so the same state is FIXTURE BROKEN (fx_skip_exit).

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
NAME="blocker-adjudication-record"

. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

SKILL=""
for c in "$ROOT/core/skills/ai-dlc-update/SKILL.md" "$ROOT/.claude/skills/ai-dlc-update/SKILL.md"; do
  [ -f "$c" ] && SKILL="$c" && break
done
[ -n "$SKILL" ] || { echo "FIXTURE ERROR: ai-dlc-update/SKILL.md not found in either layout" >&2; exit 2; }
PULL="${SKILL%/SKILL.md}/reconcile/pull.sh"

echo "HERMETIC-CONSUMED ${SKILL#"$ROOT"/}"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

echo "$NAME:"

# --- The SKIP: the installed subject predates the decisions record ------------------------------
if grep -q 'blocker-adjudication-<ts>\.md' "$SKILL" || [ ! -f "$PULL" ]; then
  echo "  SKIP  the installed ai-dlc-update predates the decisions record (SKILL.md names blocker-adjudication-<ts>.md, or reconcile/pull.sh is absent); this fixture landed ahead of its subject and asserted nothing"
  echo
  echo "$NAME: SKIP (subject predates the decisions record)"
  fx_skip_exit "$HERE"
fi

echo "HERMETIC-CONSUMED ${PULL#"$ROOT"/}"

# --- Assertion 1: step 8 still demands a citation (the anchor) ---------------
# If this stops being true the comparison below is vacuous — it would be requiring the decision
# rule to match a rule that no longer exists.
if grep -qi 'every filed defect CITES the command that found it' "$SKILL"; then
  ok "step 8 still requires a filed defect to cite its command (the anchor holds)"
else
  bad "FIXTURE STALE: step 8 no longer carries the citation requirement this fixture anchors on — the decision comparison below would pass against a skill that requires nothing"
  echo; echo "$NAME: FIXTURE STALE" >&2; exit 2
fi

# --- Assertion 2: a decision row must carry the same evidence ---------------
if grep -qi 'decision row CARRIES the command that verified it' "$SKILL"; then
  ok "a decision row must cite the command that verified it"
else
  bad "a pull decision may be recorded without evidence, while step 8 requires a receipt to FILE a defect — and a retirement deletes a consumer-owned override, so the destructive act has the weaker bar"
fi

# --- Assertion 3: inference must be labelled, not rendered as a finding ------
if grep -qi 'is an INFERENCE — label it or verify it' "$SKILL"; then
  ok "a claim about WHY a detector fired must be labelled as inference"
else
  bad "a decision may narrate a detector's motive as a finding — the shape that filed a defect against a checker correctly obeying an over-wide declaration"
fi

# --- Assertion 4: the decisions record has a named, durable home, at the driver's emission site --
# The path assignment is the line every write and the PR-body read resolve through; the PR-body
# renderer must read it, or the record reaches no reader.
pb_span="$(awk '/^pl_pr_body\(\) \{/{f=1} f{print} f && /^}/{exit}' "$PULL")"
if grep -qxF 'DECISIONS_REL="_bmad-output/ai-dlc-update/pull-decisions.tsv"' "$PULL" \
   && grep -qF '$DECISIONS_REL' <<<"$pb_span" && grep -qF '### Decisions' <<<"$pb_span"; then
  ok "pull.sh writes the decisions record at _bmad-output/ai-dlc-update/pull-decisions.tsv and pl_pr_body renders it into the PR body"
else
  bad "pull.sh no longer assigns DECISIONS_REL to _bmad-output/ai-dlc-update/pull-decisions.tsv, or pl_pr_body no longer reads and renders it — a decision then has no durable home the operator's PR review sees"
fi
if grep -qF '_bmad-output/ai-dlc-update/pull-decisions.tsv' "$SKILL"; then
  ok "SKILL.md tells the session to append its own decisions to the same record"
else
  bad "SKILL.md never names _bmad-output/ai-dlc-update/pull-decisions.tsv — the session's own decisions have no stated home"
fi

# --- Assertion 5: and it is NOT the two that cannot hold it ------------------
# Absence-shaped, so it sits behind assertion 4's presence of the real destination.
if grep -q 'record it into the report' "$SKILL"; then
  bad "an answer is still routed to 'the report' — the report is overwritten by the next dry run, so the answer is destroyed"
else
  ok "no answer or decision is routed to the report"
fi

# --- Assertion 6: a recorded decision is not authorization, and not an operator answer -------
if grep -qi 'NEVER authorizes a write on its own' "$SKILL" && grep -qF 'operator-answers-history.md' "$SKILL"; then
  ok "a decisions row explicitly does not authorize a write, and operator answers are proven by the hook-written history"
else
  bad "nothing states a decisions row is not authorization, or SKILL.md no longer names the hook-written answers history as the proof of an operator answer"
fi

# --- Assertion 7: resolution commands must be runnable as written -----------
if grep -qi 'with every placeholder resolved' "$SKILL"; then
  ok "resolution commands must carry no unresolved placeholder"
else
  bad "a resolution command may ship with a literal <dist> — a path out the operator cannot walk without guessing"
fi

echo
report_end "$NAME"
