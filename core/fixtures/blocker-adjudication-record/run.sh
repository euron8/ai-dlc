#!/usr/bin/env bash
# blocker-adjudication-record — a blocker decision must be evidenced, and its answer must have
# somewhere to live.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# Two holes on the same path, both found by an operator who had to hand-write a prompt supplying
# what the skill should have carried.
#
# ONE — the answer had nowhere to go. SKILL.md told the operator to "record it into the
# report/log for the apply run to act on". The report is a fixed filename the NEXT DRY RUN
# OVERWRITES (the same step says so), and reconcile-log-<ts>.md is not written until step 7,
# under apply. Both named destinations are unusable at the moment an answer exists: one is
# destroyed, one does not yet exist. Three dry runs in a day is normal on a real consumer.
#
# TWO — the disposition needed no evidence. Step 8's defect drain already required a cited
# command and its decisive output line for every filing. A blocker disposition required
# nothing, and RETIRE DELETES A CONSUMER-OWNED OVERRIDE. The more destructive act carried the
# weaker bar, which is the asymmetry this pins.
#
# The step-8 rule is the ANCHOR, not a copy: this fixture reads the citation requirement out of
# the drain bullet and requires the blocker bullet to carry one too. Weakening either one alone
# fails here, so the two cannot drift apart the way the grep and the review template did.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

SKILL=""
for c in "$ROOT/core/skills/ai-dlc-update/SKILL.md" "$ROOT/.claude/skills/ai-dlc-update/SKILL.md"; do
  [ -f "$c" ] && SKILL="$c" && break
done
[ -n "$SKILL" ] || { echo "FIXTURE ERROR: ai-dlc-update/SKILL.md not found in either layout" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "blocker-adjudication-record:"

# --- Assertion 1: step 8 still demands a citation (the anchor) ---------------
# If this stops being true the comparison below is vacuous — it would be requiring the blocker
# rule to match a rule that no longer exists.
if grep -qi 'every filed defect CITES the command that found it' "$SKILL"; then
  ok "step 8 still requires a filed defect to cite its command (the anchor holds)"
else
  bad "FIXTURE STALE: step 8 no longer carries the citation requirement this fixture anchors on — the blocker comparison below would pass against a skill that requires nothing"
  echo; echo "blocker-adjudication-record: FIXTURE STALE" >&2; exit 2
fi

# --- Assertion 2: a blocker disposition must carry the same evidence ---------
if grep -qi 'blocker DISPOSITION carries the command that verified it' "$SKILL"; then
  ok "a blocker disposition must cite the command that verified it"
else
  bad "step 5 lets a blocker disposition be asserted without evidence, while step 8 requires a receipt to FILE one — and RETIRE deletes a consumer-owned override, so the destructive act has the weaker bar"
fi

# --- Assertion 3: inference must be labelled, not rendered as a finding ------
if grep -qi 'is an INFERENCE — label it or verify it' "$SKILL"; then
  ok "a claim about WHY a detector fired must be labelled as inference"
else
  bad "a blocker disposition may narrate a detector's motive as a finding — the shape that filed a defect against a checker correctly obeying an over-wide declaration"
fi

# --- Assertion 4: the answer has a named, durable home ----------------------
if grep -q 'blocker-adjudication-<ts>\.md' "$SKILL"; then
  ok "adjudication answers have a named, timestamped destination"
else
  bad "no named destination for an adjudication answer — the operator must invent a filename, or lose the answer to the next dry run"
fi

# --- Assertion 5: and it is NOT the two that cannot hold it ------------------
# The precise defect was naming the report and the log. Both are still named in this file for
# other purposes, so assert the ANSWER instruction no longer routes there.
if grep -q 'record it into the report/log' "$SKILL"; then
  bad "the answer is still routed to 'the report/log' — the report is overwritten by the next dry run and the log is not written until step 7, so both destroy or postdate the answer"
else
  ok "the answer is no longer routed to the report or the pre-apply log"
fi

# --- Assertion 6: apply must READ it, or the write has no consumer ----------
# A record nothing consumes is a diary. This is the join that makes it machinery.
if awk '/Work the .HARD-\*. rows/{found=NR} END{exit !found}' "$SKILL" \
   && grep -q 'read the newest `_bmad-output/ai-dlc-update/blocker-adjudication-<ts>\.md`' "$SKILL"; then
  ok "step 7 reads the adjudication record before working the blockers"
else
  bad "step 7 never reads the adjudication record — the dry run writes a decision nothing consumes, and every blocker is re-litigated under apply"
fi

# --- Assertion 7: recording an answer is not authorization ------------------
# The incident this skill already documents is an agent treating an adjudication as a
# write order. A durable record makes that MORE tempting, not less.
if grep -qi 'NEVER authorizes a write on its own' "$SKILL"; then
  ok "the record explicitly does not authorize a write"
else
  bad "nothing states the adjudication record is not authorization — a decided blocker in a file reads as an instruction to act, which is the incident-confirmed failure mode this skill exists to prevent"
fi

# --- Assertion 8: resolution commands must be runnable as written -----------
if grep -qi 'with every placeholder resolved' "$SKILL"; then
  ok "resolution commands must carry no unresolved placeholder"
else
  bad "a resolution command may ship with a literal <dist> — a path out the operator cannot walk without guessing, which is the block one step later"
fi

echo
if [ "$fails" -eq 0 ]; then echo "blocker-adjudication-record: PASS"; exit 0; fi
echo "blocker-adjudication-record: $fails assertion(s) FAILED" >&2
exit 1
