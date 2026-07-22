#!/usr/bin/env bash
# inflight-row-shape — assert In-Flight Teammates carries rows, never struck rows.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# gate-validation.md and _gate-procedures.md both say a row is DELETED at join and
# that the section carries "no struck-through history". Two other core files said
# the opposite: route.md -- the file that CREATES the section, and therefore the
# schema a lead reads first -- and implementation.md, both saying rows are "struck
# at join". Core contradicted itself two homes to two, and the lead followed the
# pair it met first.
#
# Measured in the reference consumer at sprint 296: the section held 7 struck-
# through consumed rows and 302 lines of prose, 29.7 KB -- 28% of a snapshot at
# 446% of budget, inside a CANONICAL section, where v0.118.0's closed-set check
# cannot see it. That is the `Teammate Ledger (detail)` v0.118.0 deleted as an
# invented section, re-grown in a legal home.
#
# STRIKETHROUGH ONLY, NOT A PROSE CAP. Measured across 25 historical snapshots in
# that consumer: zero struck rows in all 25, seven in the live file. A prose-line
# cap was measured too and dropped -- all 25 carry some In-Flight prose (1-8 lines
# saying what is outstanding), so the cap needed a constant fitted to sit between
# them and the violations. Assertion 3 pins that decision: prose alone must NOT
# fail, or the rule silently became the one that was rejected.
#
# The snapshots below are deliberately TINY. Every red must come from the In-Flight
# check, never from the byte budget. Assertion 5 proves it.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-artifact-budget.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-artifact-budget.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/validate-artifact-budget.sh" ]; then
  VALIDATOR="$ROOT/scripts/validate-artifact-budget.sh"
else
  echo "FIXTURE ERROR: validate-artifact-budget.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts/ (distribution), $ROOT/scripts/ (consumer)" >&2
  exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output" || exit 2
SNAP="$WORK/_bmad-output/pipeline-snapshot.md"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# The seven canonical sections, with whatever body is passed for In-Flight.
seed() { # seed <in-flight-body>
  { printf '# Pipeline Snapshot\n\n'
    printf '## Pipeline Position\n- variant: carry-over\n\n'
    printf '## Sprint Context\n- sprint_id: 296\n\n'
    printf '## Recent Activity\n1. routed\n\n'
    printf '## Open Items\nnone\n\n'
    printf '## Locked Decisions\nnone\n\n'
    printf '## In-Flight Teammates\n%s\n\n' "$1"
    printf '## Context Reminders\n- context_reminders_sent: none\n\n'
  } > "$SNAP"
}

run_validator() { # run_validator [script-path]
  local v="${1:-$VALIDATOR}"
  bash "$v" --root "$WORK" --only pipeline-snapshot.md >"$WORK/out.txt" 2>&1
  echo "$?"
}

expect() { # expect <want-status> <label>
  local got; got="$(run_validator)"
  [ "$got" = "$1" ] && ok "$2" || { bad "$2 -- expected exit $1, got $got"; sed 's/^/        /' "$WORK/out.txt"; }
}

HEADER='| agent | role | deliverable | dispatched-at | status |
|---|---|---|---|---|'

echo "inflight-row-shape"

# --- 1. Live and idle-reusable rows both pass ----------------------------------
# The state the column exists to express. A teammate that has delivered but is
# still reachable is a row, not history -- and must not need a strikethrough to
# say so, or the whole change is decorative.
seed "$HEADER
| \`dev-s296-story-2\` | \`dev\` | docs/reviews/x.md | 2026-07-22 | in-flight |
| \`qa-s296-story-1\` | \`qa\` | docs/reviews/y.md | 2026-07-22 | idle-reusable |"
expect 0 "in-flight and idle-reusable rows both pass"

# --- 2. A STRUCK ROW IS REFUSED, AND NAMED -------------------------------------
# The bare assertion is "exit 1". The one that matters is that the output names
# the offending row: a FAIL that does not say which row is a FAIL the lead
# resolves by trimming prose around a row whose problem is that it still exists.
seed "$HEADER
| ~~\`dev-s296-story-1\`~~ | \`dev-escalated\` | DELIVERED + CONSUMED | 2026-07-22 | — |"
expect 1 "a struck row is refused"
if grep -q 'dev-s296-story-1' "$WORK/out.txt"; then
  ok "  and the offending row is named in the output"
else
  bad "  the offending row is NOT named -- lead cannot act on this verdict"
fi
# The red must be the In-Flight check's alone. This snapshot is a few hundred
# bytes; if the byte budget were what tripped, the assertion would be vacuous.
if grep -q 'over the Rule 25(d) budget' "$WORK/out.txt"; then
  bad "  CONFOUNDED: the byte budget also fired -- exit 1 proves nothing here"
else
  ok "  and the byte budget stayed quiet (the red is the In-Flight check's alone)"
fi
# And it must be reported as its own verdict, not folded into the schema one --
# they route the lead to different remedies.
if grep -q 'struck-through row' "$WORK/out.txt" && ! grep -q 'seven-section schema' "$WORK/out.txt"; then
  ok "  and it is a separate verdict from the schema check"
else
  bad "  the verdict was folded into the schema check -- wrong remedy for the lead"
fi

# --- 3. PROSE ALONE DOES NOT FAIL ----------------------------------------------
# Pins the measured decision. All 25 historical snapshots carry In-Flight prose;
# failing on it would need a fitted constant, which is the candidate that was
# rejected. If this assertion ever goes red, the rejected rule shipped by accident.
seed '**None in flight.** Both rows discharged; no wait-beat is owed and no
re-dispatch is warranted on either. Rule 29 governs the resume: the deliverable
file IS the handle, and a missing return value is NOT death.'
expect 0 "prose without a struck row still passes (the rejected prose-cap stays rejected)"

# --- 4. An empty table passes --------------------------------------------------
# Nothing in flight is the normal state and must never be a finding.
seed "$HEADER"
expect 0 "an empty table passes"

# --- 5. THE MUTATION TEST — prove assertion 2's red came from the new code ------
# Remove the In-Flight call from a COPY and re-run assertion 2's input. If it
# still fails, something else was producing the red.
MUTANT="$WORK/mutant.sh"
sed '/check_inflight_rows "\$f" "\$rel"/d' "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the call site was renamed" >&2
  echo "  update the sed pattern in assertion 5 to match the real call" >&2
  exit 2
fi
seed "$HEADER
| ~~\`dev-s296-story-1\`~~ | \`dev-escalated\` | DELIVERED + CONSUMED | 2026-07-22 | — |"
mutant_status="$(run_validator "$MUTANT")"
if [ "$mutant_status" = "0" ]; then
  ok "MUTATION: removing the In-Flight check makes assertion 2 go green"
else
  bad "MUTATION: assertion 2 still fails (exit $mutant_status) without the check -- it proves nothing"
fi

# --- 6. Strikethrough OUTSIDE the section is not this check's business ---------
# The scan is section-scoped. Recent Activity legitimately strikes superseded
# entries, and indicting them would make the check noise -- noisy gates get
# ignored, which is the reasoning the budget's grace band already runs on.
{ printf '# Pipeline Snapshot\n\n'
  printf '## Pipeline Position\n- variant: carry-over\n\n'
  printf '## Sprint Context\n- sprint_id: 296\n\n'
  printf '## Recent Activity\n1. ~~superseded by item 4~~\n\n'
  printf '## Open Items\nnone\n\n'
  printf '## Locked Decisions\nnone\n\n'
  printf '## In-Flight Teammates\n%s\n\n' "$HEADER"
  printf '## Context Reminders\n- context_reminders_sent: none\n\n'
} > "$SNAP"
expect 0 "a strikethrough in another section is out of scope"

# --- 7. --warn-only still exits 0 ----------------------------------------------
# retro's Rule 25(d) posture: the sprint is over, blocking helps nobody. This
# verdict must follow the same rule as the other two, or retro starts failing on a
# snapshot it can no longer do anything about.
seed "$HEADER
| ~~\`dev-s296-story-1\`~~ | \`dev-escalated\` | DELIVERED + CONSUMED | 2026-07-22 | — |"
bash "$VALIDATOR" --root "$WORK" --only pipeline-snapshot.md --warn-only >"$WORK/out.txt" 2>&1
warn_status=$?
if [ "$warn_status" = "0" ] && grep -q 'struck-through row' "$WORK/out.txt"; then
  ok "--warn-only reports the struck row and still exits 0"
else
  bad "--warn-only exit $warn_status / message missing -- retro posture broken"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "inflight-row-shape: PASS"
  exit 0
fi
echo "inflight-row-shape: FAIL ($fails assertion(s))"
exit 1
