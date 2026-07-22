#!/usr/bin/env bash
# whole-read-pool — assert the planning-artifact budget is derived from its reader,
# and that the reader's window is RESOLVED rather than inherited.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# WHAT THIS REPLACED.
#
# Four per-file constants (prd 60000, product-brief 60000, carry-over-backlog
# 40000, architecture 60000) with no derivation: no ADR, no measurement, no named
# reader, and a per-artifact env override. A physical limit does not ship with an
# override flag. The gate they backed is a HARD_BLOCK at sprint start over
# artifacts holding LOCKED requirements (Rule 13) that no rule retires, so growth
# is monotonic and the gate was eventually unpassable -- with "relocate locked
# requirements" as its standing remedy. The reference consumer ran that relocation
# at S242, S247 and S274; it grew back every time.
#
# Exactly one agent whole-reads the four: the Rule-24 analyst at
# carry-over-evaluation.md section 1 (Rule 25(b)). So the binding quantity is the
# SUM against ONE window, and the pool is that window's 33%.
#
# THE PART THAT IS CORE'S AND NOT THE CONSUMER'S.
#
# The consumer that derived this wrote the window in as a literal 1,000,000, with
# a comment telling a human "if that model line changes, THIS NUMBER CHANGES.
# Re-derive; do not inherit." Core cannot execute an instruction to a human, and
# the number is not core's to inherit: core ships team-roles/analyst.md as a
# TEMPLATE that setup fills per project. A hardcoded 1,000,000 would hand a
# 200K-window analyst a pool 1.65x its entire context -- a fail-open at a
# HARD_BLOCK, on the very gate that exists to stop the analyst blowing its window
# one step later.
#
# Assertions 1-4 are that resolution. Assertion 4 is the one that matters: unknown
# must fall to the SMALLER window, never the larger.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-artifact-budget.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-artifact-budget.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-artifact-budget.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-artifact-budget.sh"
else
  echo "FIXTURE ERROR: validate-artifact-budget.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts/ (distribution), $ROOT/scripts/ (consumer)" >&2
  exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output/planning-artifacts" "$WORK/docs" "$WORK/.claude/team-roles" || exit 2

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# The analyst role file, in the layout install.sh writes (.claude/team-roles/).
role() { # role <personal-model-line>
  printf '# Analyst\n\n## Model\n\n- Personal: `/model %s`\n- Bedrock: `/model x`\n' "$1" \
    > "$WORK/.claude/team-roles/analyst.md"
}

# Size the four planning artifacts. Arg is total KB, split evenly across them.
artifacts() { # artifacts <kb-each>
  for f in "$WORK/_bmad-output/planning-artifacts/prd.md" \
           "$WORK/_bmad-output/planning-artifacts/product-brief.md" \
           "$WORK/_bmad-output/planning-artifacts/carry-over-backlog.md" \
           "$WORK/docs/architecture.md"; do
    head -c "$(( $1 * 1024 ))" /dev/zero | tr '\0' 'x' > "$f"
  done
}

run() {
  bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
  echo "$?"
}
pool_of() { sed -n 's/^whole-read pool     : \([0-9]*\) tok.*/\1/p' "$WORK/out.txt" | head -1; }

echo "whole-read-pool"

artifacts 1

# --- 1. A [1m] analyst resolves to the 1M window -------------------------------
# Reproduces the reference consumer exactly: its analyst.md carries
# `claude-sonnet-5[1m]` and its pool is 330,000.
role 'claude-sonnet-5[1m]'
run >/dev/null
if [ "$(pool_of)" = "330000" ]; then
  ok "a [1m] analyst resolves to a 330000-tok pool"
else
  bad "a [1m] analyst resolved to '$(pool_of)', expected 330000"
fi

# --- 2. A plain analyst resolves to the 200K window ----------------------------
role 'claude-sonnet-5'
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "a non-1m analyst resolves to a 66000-tok pool"
else
  bad "a non-1m analyst resolved to '$(pool_of)', expected 66000"
fi

# --- 3. AN UNFILLED TEMPLATE FALLS TO THE SMALLER WINDOW -----------------------
# This is what core itself ships. Getting 1,000,000 here would mean every consumer
# inherits the reference consumer's window until setup happens to fill the file.
role '{analyst_model_personal}'
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "an unfilled {analyst_model_personal} template falls back to 66000, not 330000"
else
  bad "an unfilled template resolved to '$(pool_of)' -- core is shipping an inherited window"
fi

# --- 4. A MISSING ROLE FILE FALLS TO THE SMALLER WINDOW ------------------------
# The direction of the unknown case is the whole safety property. Unknown must
# tighten the gate; resolving unknown to 1M is a fail-open at a HARD_BLOCK.
rm -f "$WORK/.claude/team-roles/analyst.md"
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "a missing role file falls back to 66000 -- unknown tightens, never opens"
else
  bad "a missing role file resolved to '$(pool_of)' -- unknown opened the gate"
fi

# --- 5. The pool actually BINDS ------------------------------------------------
# A budget that cannot fail is not a budget. Controls in both directions, so
# neither verdict is an accident of the fixture's file sizes.
role 'claude-sonnet-5[1m]'
artifacts 1
status="$(run)"
if [ "$status" = "0" ] && grep -q '  ok  WHOLE-READ POOL' "$WORK/out.txt"; then
  ok "four small artifacts pass the pool (exit 0)"
else
  bad "four small artifacts did not pass -- exit $status"
fi

artifacts 400   # 4 x 400 KB / 4 = 409,600 tok, past 330000 + 10%
status="$(run)"
if [ "$status" = "1" ] && grep -q '^OVER  WHOLE-READ POOL' "$WORK/out.txt"; then
  ok "four oversized artifacts breach the pool (exit 1)"
else
  bad "four oversized artifacts did not breach -- exit $status"
  grep -E 'POOL' "$WORK/out.txt" | sed 's/^/        /'
fi

# --- 6. NO PER-FILE PLANNING BUDGET SURVIVES -----------------------------------
# The subtraction is the point: four constants became one derived number. A
# leftover per-file row would re-impose an underived limit that the pool's own
# remedy text says is not a remedy, and the two would disagree.
if grep -qE '^(prd|product-brief|carry-over-backlog|architecture)\.md\|' "$VALIDATOR"; then
  bad "a per-file planning budget is still in the BUDGETS table -- the subtraction did not happen"
else
  ok "no per-file planning budget remains in the BUDGETS table"
fi
# And the breach above must be reported as the POOL, not as four files.
if grep -qE '^OVER  _bmad-output/planning-artifacts/prd\.md' "$WORK/out.txt"; then
  bad "prd.md was also reported per-file -- the lead gets two verdicts and the wrong remedy"
else
  ok "  and the breach is reported once, as a sum"
fi

# --- 7. --only pipeline-snapshot.md does NOT drag the pool in ------------------
# Check 14 and the sub-step path only ever ask about the snapshot. Reporting a
# planning-artifact breach there would fail the wrong gate on the wrong artifact
# with a remedy (consolidate) that must never run mid-sprint.
artifacts 400
printf '## Pipeline Position\nx\n' > "$WORK/_bmad-output/pipeline-snapshot.md"
bash "$VALIDATOR" --root "$WORK" --only pipeline-snapshot.md >"$WORK/out.txt" 2>&1
only_status=$?
if [ "$only_status" = "0" ] && ! grep -q 'WHOLE-READ POOL' "$WORK/out.txt"; then
  ok "--only pipeline-snapshot.md ignores the pool entirely"
else
  bad "--only pipeline-snapshot.md exit $only_status and/or reported the pool -- gates would fail on the wrong artifact"
fi

# --- 8. THE MUTATION TEST — prove assertions 3/4 measure the resolver ----------
# Flip BOTH fallback sites to 1M on a COPY and demand the two unknown inputs now
# report 330000. There are two sites -- a missing role file returns early, an
# unrecognised model falls through the case -- and a mutation covering only one
# leaves the other's green unexplained. The first draft of this fixture mutated
# only the case arm and this assertion correctly refused to pass.
MUTANT="$WORK/mutant.sh"
sed "s/printf '200000'/printf '1000000'/g" "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- resolve_reader_window was rewritten" >&2
  echo "  update the sed pattern in assertion 8 to match the real fallback arms" >&2
  exit 2
fi
if [ "$(grep -c "printf '1000000'" "$MUTANT")" -lt 2 ]; then
  echo "FIXTURE ERROR: mutation hit fewer than 2 fallback sites -- one path is uncovered" >&2
  exit 2
fi
artifacts 1
mut_fails=0
rm -f "$WORK/.claude/team-roles/analyst.md"
bash "$MUTANT" --root "$WORK" >"$WORK/out.txt" 2>&1
[ "$(pool_of)" = "330000" ] || { mut_fails=1; printf '        missing role file still reports %s\n' "$(pool_of)"; }
role '{analyst_model_personal}'
bash "$MUTANT" --root "$WORK" >"$WORK/out.txt" 2>&1
[ "$(pool_of)" = "330000" ] || { mut_fails=1; printf '        unfilled template still reports %s\n' "$(pool_of)"; }
if [ "$mut_fails" -eq 0 ]; then
  ok "MUTATION: pinning both fallbacks to 1M makes BOTH unknown cases report 330000"
else
  bad "MUTATION: an unknown case is not produced by the fallback -- assertions 3-4 prove nothing there"
fi

# --- 9. The env override still works, and says so ------------------------------
# The escape hatch survives, but it must be visible: a pool the operator raised is
# a different claim from a pool the reader derived, and the output must not
# conflate them.
role 'claude-sonnet-5'
artifacts 1
AI_DLC_READER_WINDOW_TOKENS=600000 bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
if [ "$(pool_of)" = "198000" ] && grep -q 'AI_DLC_READER_WINDOW_TOKENS' "$WORK/out.txt"; then
  ok "the env override applies and names itself as the source"
else
  bad "override gave pool '$(pool_of)' and/or did not name its source"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "whole-read-pool: PASS"
  exit 0
fi
echo "whole-read-pool: FAIL ($fails assertion(s))"
exit 1
