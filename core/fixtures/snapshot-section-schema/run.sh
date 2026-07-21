#!/usr/bin/env bash
# snapshot-section-schema — assert the snapshot's seven-section schema is a CLOSED set.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# gate-validation.md Check 14 enumerates seven sections to REFRESH. It never said
# "and no others," and nothing counted them. So the schema was a REQUIRED-set, and
# an eighth section was invisible to every check until total BYTES breached --
# by which point validate-artifact-budget.sh's own remedy string was telling the
# lead to "trim to its 7-section schema" while nothing on disk could evaluate one.
#
# Measured in the reference consumer at sprint 296, mid-sprint: TEN `## ` sections
# at 141% of budget (156% an hour later, still growing). Three were lead invention
# that no hook, no step and no script writes -- `Teammate Ledger (detail)` 5.7 KB,
# `Discovery phase -- CLOSED` 1.9 KB, `Post-compact recovery log` 1.4 KB. 9.0 KB of
# 34 KB, accumulated BETWEEN gates, on the artifact that is whole-read at every
# gate, on every resume, and after every compaction.
#
# The snapshots below are deliberately TINY -- kilobytes under the 6000-token
# budget. That is the point: every red in this fixture must come from the SCHEMA
# check, never from the byte budget. Assertion 5 proves it by removing the schema
# check and demanding the same input go green.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Two layouts, both derived from install.sh's mapping -- NOT guessed. install.sh
# maps `core/scripts/<x>` to `scripts/<x>` at the project root, so the validator
# lands in a different tree on a consumer than in the distribution.
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

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

SNAP="$WORK/_bmad-output/pipeline-snapshot.md"

# Write a snapshot carrying the seven canonical sections, plus whatever extra
# headings are passed as arguments.
seed() {
  { printf '# Pipeline Snapshot\n\n'
    printf '## Pipeline Position\n- variant: carry-over\n\n'
    printf '## Sprint Context\n- sprint_id: 296\n\n'
    printf '## Recent Activity\n1. routed\n\n'
    printf '## Open Items\nnone\n\n'
    printf '## Locked Decisions\nnone\n\n'
    printf '## In-Flight Teammates\nnone\n\n'
    printf '## Context Reminders\n- context_reminders_sent: none\n\n'
    for h in "$@"; do printf '## %s\nbody\n\n' "$h"; done
  } > "$SNAP"
}

# Run the validator against the fixture root; echo its exit status.
run_validator() { # run_validator [script-path]
  local v="${1:-$VALIDATOR}"
  bash "$v" --root "$WORK" --only pipeline-snapshot.md >"$WORK/out.txt" 2>&1
  echo "$?"
}

expect_status() { # expect_status <want> <label>
  local got; got="$(run_validator)"
  [ "$got" = "$1" ] && ok "$2" || bad "$2 -- expected exit $1, got $got"
}

echo "snapshot-section-schema"

# --- 1. The canonical seven pass -----------------------------------------------
seed
expect_status 0 "the seven canonical sections pass"

# --- 2. AN EIGHTH SECTION IS REFUSED, AND NAMED --------------------------------
# The bare assertion is "exit 1". The one that matters is that the message names
# the offender: a FAIL that does not say WHICH section is a FAIL the lead resolves
# by trimming bytes out of a section that should not exist at all.
seed 'Teammate Ledger (detail)'
expect_status 1 "an eighth section is refused"
if grep -q 'Teammate Ledger (detail)' "$WORK/out.txt"; then
  ok "  and the offending section is named in the output"
else
  bad "  the offending section is NOT named -- lead cannot act on this verdict"
fi

# Assertion 2 must not be passing for the wrong reason. This snapshot is a few
# hundred bytes; if the byte budget were what tripped, the fixture would be
# vacuous. Prove the budget is quiet on this input.
if grep -q 'over the Rule 25(d) budget' "$WORK/out.txt"; then
  bad "  CONFOUNDED: the byte budget also fired -- exit 1 proves nothing here"
else
  ok "  and the byte budget stayed quiet (the red is the schema's alone)"
fi

# --- 3. A RENAMED canonical section is an invented one --------------------------
# The failure this catches is subtler than an addition: In-Flight Teammates is the
# dispatch ledger, and a lead that renames it has silently removed the section the
# recovery path looks for while leaving the bytes in place.
{ printf '# Pipeline Snapshot\n\n'
  printf '## Pipeline Position\nx\n\n## Sprint Context\nx\n\n## Recent Activity\nx\n\n'
  printf '## Open Items\nx\n\n## Locked Decisions\nx\n\n'
  printf '## Teammate Ledger\nx\n\n'
  printf '## Context Reminders\nx\n\n'
} > "$SNAP"
expect_status 1 "a RENAMED canonical section is refused"

# --- 4. Decoration is not invention --------------------------------------------
# A prefix match, deliberately. `## In-Flight Teammates (none)` is that section
# wearing a hat; failing it would make the check noise, and noisy gates get
# ignored -- the same reasoning as the budget's grace band.
seed
sed 's/^## In-Flight Teammates$/## In-Flight Teammates (none)/' "$SNAP" > "$SNAP.tmp" \
  && mv "$SNAP.tmp" "$SNAP"
grep -q '^## In-Flight Teammates (none)$' "$SNAP" || { echo "FIXTURE ERROR: sed no-op" >&2; exit 2; }
expect_status 0 "a decorated canonical heading still passes"

# --- 5. THE MUTATION TEST — prove assertion 2's red came from the new code ------
# Remove the schema call from a COPY of the validator and re-run assertion 2's
# input. If it still fails, something else was producing the red and assertions
# 1-4 are measuring nothing. This is the control the first KISS differential and
# the v0.71.0 proof both lacked.
MUTANT="$WORK/mutant.sh"
sed '/check_snapshot_sections "\$f" "\$rel"/d' "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the call site was renamed" >&2
  echo "  update the sed pattern in assertion 5 to match the real call" >&2
  exit 2
fi
seed 'Teammate Ledger (detail)'
mutant_status="$(run_validator "$MUTANT")"
if [ "$mutant_status" = "0" ]; then
  ok "MUTATION: removing the schema check makes assertion 2 go green"
else
  bad "MUTATION: assertion 2 still fails (exit $mutant_status) without the schema check -- it proves nothing"
fi

# --- 6. --warn-only still exits 0 ----------------------------------------------
# retro's Rule 25(d) posture: the sprint is over, blocking it helps nobody. The
# schema verdict must follow the same rule as the byte verdict, or retro starts
# failing on a snapshot it can no longer do anything about.
seed 'Teammate Ledger (detail)'
bash "$VALIDATOR" --root "$WORK" --only pipeline-snapshot.md --warn-only >"$WORK/out.txt" 2>&1
warn_status=$?
if [ "$warn_status" = "0" ] && grep -q 'seven-section schema' "$WORK/out.txt"; then
  ok "--warn-only reports the schema breach and still exits 0"
else
  bad "--warn-only exit $warn_status / message missing -- retro posture broken"
fi

# --- 7. THE CHANNELS LEAVE NOTHING IN THE PROJECT ROOT --------------------------
# Both channels used to be `$ROOT/.ai-dlc-*.tmp`. Nothing gitignores those, so a
# killed run left them untracked in the consumer's project root where a broad
# `git add -A` commits them -- and a leftover is indistinguishable, to a READER,
# from a fresh verdict (a v0.118.1 reconcile report quoted a 12-minute-old one as
# current evidence). They live in a per-run mktemp dir now. Assert the absence,
# because "no litter" is the property, not "the litter is cleared".
seed 'Teammate Ledger (detail)'
run_validator >/dev/null
stray="$(find "$WORK" -maxdepth 1 -name '*.tmp' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$stray" = "0" ]; then
  ok "a failing run leaves no temp file in the project root"
else
  bad "a failing run left $stray temp file(s) in the project root"
fi

# --- 8. THE BYTE CHANNEL STILL FIRES --------------------------------------------
# Guards the fix that moved the OVER writer off a hardcoded `$ROOT/...tmp` path and
# onto $BREACH_FILE. Had the writer kept the old path while the reader moved, the
# reader would have found an empty file and the byte budget would have gone SILENT
# -- passing every over-budget snapshot, with no error anywhere. The schema
# assertions above would not have noticed: they only ever assert the budget is
# QUIET. This is the one that would have caught it.
seed
head -c 40000 /dev/zero | tr '\0' 'x' >> "$SNAP"
run_validator >/dev/null
if grep -q '^OVER ' "$WORK/out.txt" && grep -q 'over the Rule 25(d) budget' "$WORK/out.txt"; then
  ok "an over-budget snapshot still reaches the byte-budget reader"
else
  bad "the byte channel went SILENT -- writer and reader disagree on the temp path"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "snapshot-section-schema: PASS"
  exit 0
fi
echo "snapshot-section-schema: FAIL ($fails assertion(s))"
exit 1
