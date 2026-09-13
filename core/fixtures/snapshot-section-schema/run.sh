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
# by which point validate-artifact-budget.sh's own remedy string was pointing the
# lead at a schema nothing on disk could evaluate.
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

# THE PRE-PUSH GATE INHERITS EVERY AI_DLC_* TUNABLE A CONSUMER SET IN settings.json, and a
# fixture that drives a validator while inheriting them tests the CONFIG, not the CODE. 33
# sibling fixtures already carry this loop; these three did not, and it cost a real consumer a
# red suite on a legitimate configuration.
#
# THE FAILURE IS WORSE THAN A RED SUITE, because the arms here set these keys THEMSELVES to test
# both postures. An ambient value silently rewrites the arm that tests the DEFAULT into a second
# copy of the arm that tests the override -- so the pass that remains is asserting the same
# thing twice and the default is no longer covered at all. Measured, ambient vs clean:
#   inflight-row-shape            AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid   rc 0 -> 1
#   snapshot-supersession-marker  AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid   rc 0 -> 1
#   snapshot-section-schema       AI_DLC_SNAPSHOT_EXTRA_SECTIONS=...     rc 0 -> 1
# Control, two fixtures that already carry the loop: unchanged under both.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done


HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Two layouts, both derived from install.sh's mapping -- NOT guessed. install.sh
# maps `core/scripts/<x>` to `scripts/<x>` at the project root, so the validator
# lands in a different tree on a consumer than in the distribution.
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

# --- A PROJECT-DECLARED eighth section, and the two controls that keep it honest ---
#
# The closed set exists because a lead invented three sections mid-sprint. A project
# that legitimately carries an eighth must be able to say so WITHOUT shadowing the
# whole rule -- the reference consumer wrote an override replacing Check 14 in full to
# do it, which also froze every other line of that section at its base_sha. So the set
# is data now. These three assertions are the difference between a declaration and an
# off-switch: undeclared still fails, the DECLARED name passes, and declaring some
# OTHER name does not admit this one.
seed "Deploy Baseline"

got="$(run_validator)"
if [ "$got" = "1" ] && grep -q 'unknown section: ## Deploy Baseline' "$WORK/out.txt"; then
  ok "an UNDECLARED eighth section still fails (the closed set is intact by default)"
else
  bad "the eighth section passed with nothing declared -- exit $got"
fi

got="$(AI_DLC_SNAPSHOT_EXTRA_SECTIONS='Deploy Baseline' run_validator)"
if [ "$got" = "0" ] && ! grep -q 'unknown section' "$WORK/out.txt"; then
  ok "a PROJECT-DECLARED eighth section is admitted"
else
  bad "a declared section was still rejected -- exit $got"; sed 's/^/        /' "$WORK/out.txt"
fi

got="$(AI_DLC_SNAPSHOT_EXTRA_SECTIONS='Something Else' run_validator)"
if [ "$got" = "1" ] && grep -q 'unknown section: ## Deploy Baseline' "$WORK/out.txt"; then
  ok "CONTROL: declaring a DIFFERENT name does not admit this one (a declaration, not an off-switch)"
else
  bad "any non-empty declaration admitted an undeclared section -- exit $got"
fi

# =============================================================================
# ENTRY SHAPE: A DATED ACTIVITY ENTRY UNDER THE WRONG CANONICAL HEADING.
#
# The schema assertions above are about HEADINGS. These are about what sits
# UNDER one, and the two are independent: every snapshot below carries exactly
# the canonical seven, so the schema channel must stay silent through all of it
# or these arms are measuring the wrong verdict.
#
# WHY THESE ARMS NEED A MUTANT AND THE ONES ABOVE DID NOT. This finding is a
# WARN that never touches the exit status, on purpose -- the validator runs on
# the blocking sub-step path and a filing error must not wedge a pipeline. So a
# copy of the arm that reports nothing at all produces byte-identical exit codes
# on every input, forever, and no gate anywhere would notice. The mutants at the
# end of this block are the only thing standing between that and a green suite.
# =============================================================================

# Seven canonical headings, and whatever lines the caller wants under each.
# Every arm seeds from the CONSUMER'S OWN observed shapes, never from what the
# arm's regex accepts: plain, bold, backticked, ordered, mid-line, indented.
seed_entries() { # seed_entries <pipeline-position-extra> <sprint-context-body> <recent-activity-body> <inflight-body> <context-reminders-body>
  { printf '# Pipeline Snapshot\n\n'
    printf '## Pipeline Position\n- variant: carry-over\n%s\n\n' "$1"
    printf '## Sprint Context\n%s\n\n' "$2"
    printf '## Recent Activity\n%s\n\n' "$3"
    printf '## Open Items\nnone\n\n'
    printf '## Locked Decisions\nnone\n\n'
    printf '## In-Flight Teammates\n%s\n\n' "$4"
    printf '## Context Reminders\n%s\n\n' "$5"
  } > "$SNAP"
}

# The WARN and its detail rows both go to stderr/stdout of the same run; run_validator
# already captures both into out.txt.
entry_warn_count() { grep -c '^WARN: pipeline-snapshot.md files' "$WORK/out.txt" 2>/dev/null || true; }
entry_rows_for()   { grep -c "dated entry under ## $1" "$WORK/out.txt" 2>/dev/null || true; }

# --- E1. OFFENDER under Sprint Context is REPORTED, by section and by line -----
seed_entries '' '- 2026-09-12T02:53Z: routed fresh, step 1a' '- 2026-09-12T03:00Z: this one belongs here' 'none' '- context_reminders_sent: none'
got="$(run_validator)"
n="$(entry_rows_for 'Sprint Context')"
# The line number is DERIVED from the seeded file, never hardcoded: a hardcoded one
# goes wrong the next time `seed_entries` gains a line, and a wrong constant beside a
# correct arm reads as a regression in the subject.
want_line="$(grep -n '2026-09-12T02:53Z' "$SNAP" | head -1 | cut -d: -f1)"
if [ "$n" -ge 1 ] && [ -n "$want_line" ] && grep -q "line ${want_line}:" "$WORK/out.txt"; then
  ok "ENTRY: a dated entry under ## Sprint Context is reported, at its real line ($want_line)"
else
  bad "ENTRY: the offender under ## Sprint Context was NOT reported at line ${want_line:-?} (rows=$n)"
fi
# It must be the ENTRY channel that fired, not the schema one -- these headings are canonical.
if grep -q 'unknown section' "$WORK/out.txt"; then
  bad "  CONFOUNDED: the schema channel also fired on the canonical seven"
else
  ok "  and the schema channel stayed quiet (the finding is the entry arm's alone)"
fi

# --- E2. THE EXIT STATUS IS UNCHANGED BY THE FINDING, ON EVERY FLAG ------------
# This is the arm that kills the "make it a FAIL" wrong fix. The validator runs at
# a sub-step where exit 1 means TRIM NOW; a misfiled line must not produce that.
# --fail-on is included because it is the flag that hardens the BUDGET verdict, and
# a future author reaching for it is the realistic way this becomes blocking.
if [ "$got" = "0" ]; then
  ok "ENTRY: the finding does not change the exit status (default run, exit 0)"
else
  bad "ENTRY: a misfiled line changed the exit status to $got -- it now wedges the sub-step path"
fi
bash "$VALIDATOR" --root "$WORK" --only pipeline-snapshot.md --fail-on pipeline-snapshot.md >"$WORK/out.txt" 2>&1
failon_status=$?
if [ "$failon_status" = "0" ] && [ "$(entry_warn_count)" = "1" ]; then
  ok "ENTRY: --fail-on does not harden this finding either (exit 0, still reported)"
else
  bad "ENTRY: --fail-on turned the WARN into a failure (exit $failon_status) or silenced it"
fi

# --- E3. NEAR-MISS: a MID-LINE timestamp under Pipeline Position ---------------
# Measured on the reference consumer: 396 of its 514 snapshot revisions carry one.
# An arm that reports these reports 77% of the corpus and is noise.
seed_entries '- last_gate_passed: planning at 2026-09-12T22:14:00Z' '- sprint_id: 311' '- 2026-09-12T03:00Z: belongs here' 'none' '- none'
got="$(run_validator)"
if [ "$(entry_rows_for 'Pipeline Position')" = "0" ] && [ "$got" = "0" ]; then
  ok "ENTRY NEAR-MISS: a MID-line timestamp under ## Pipeline Position is not reported"
else
  bad "ENTRY NEAR-MISS: Pipeline Position row data was indicted -- this arm reports most of the corpus"
fi

# --- E4. NEAR-MISS: an INDENTED continuation line ------------------------------
# Admitting leading blanks before the bullet adds 178 lines across the consumer's
# history, every one a soft-wrapped continuation whose predecessor is non-empty.
seed_entries '  2026-09-12T22:20:00Z continuation of the line above' '- sprint_id: 311' '- 2026-09-12T03:00Z: belongs here' 'none' '- none'
run_validator >/dev/null
if [ "$(entry_rows_for 'Pipeline Position')" = "0" ]; then
  ok "ENTRY NEAR-MISS: an INDENTED dated continuation line is not reported"
else
  bad "ENTRY NEAR-MISS: an indented continuation was indicted -- soft-wrapped prose now reds"
fi

# --- E5. NEAR-MISS: an UNBULLETED dated line under In-Flight Teammates ---------
# All 8 In-Flight hits in the consumer's history are ONE line: ff5920ff3:151, the
# second line of a sentence that began on the line above. The required bullet is
# what holds this arm's false-positive set at zero.
seed_entries '' '- sprint_id: 311' '- 2026-09-12T03:00Z: belongs here' \
  '2026-09-09T14:05:45Z; a wrapped prose continuation, not a row' '- none'
run_validator >/dev/null
if [ "$(entry_rows_for 'In-Flight Teammates')" = "0" ]; then
  ok "ENTRY NEAR-MISS: an UNBULLETED dated line under ## In-Flight Teammates is not reported"
else
  bad "ENTRY NEAR-MISS: a wrapped prose continuation was indicted as a misfiled entry"
fi
# ...and the same section with a BULLET is still in scope. Without this, "In-Flight
# is quiet" would pass equally against an arm that exempts the whole section, which
# is a different and weaker mechanism than the one being shipped.
seed_entries '' '- sprint_id: 311' '- 2026-09-12T03:00Z: belongs here' \
  '- 2026-09-09T14:05:45Z: a genuinely bulleted dated entry' '- none'
run_validator >/dev/null
if [ "$(entry_rows_for 'In-Flight Teammates')" -ge 1 ]; then
  ok "ENTRY: a BULLETED dated entry under ## In-Flight Teammates IS reported (excluded by grammar, not by section)"
else
  bad "ENTRY: In-Flight Teammates is exempt as a SECTION -- a real misfile there would be invisible"
fi

# --- E6. NEAR-MISS: the entry under its OWN section ----------------------------
seed_entries '' '- sprint_id: 311' \
  '- 2026-09-12T03:00Z: plain
- **2026-09-12T04:00Z** bold
1. `2026-09-12T05:00Z` ordered and backticked' 'none' '- none'
got="$(run_validator)"
if [ "$(entry_warn_count)" = "0" ] && [ "$got" = "0" ]; then
  ok "ENTRY NEAR-MISS: plain, bold and ordered entries under ## Recent Activity are all silent"
else
  bad "ENTRY NEAR-MISS: correctly-filed entries were reported -- the arm indicts its own remedy"
fi

# --- E7. THE DECORATED FORMS ARE CAUGHT WHEN MISFILED --------------------------
# The mirror of E6, and it is the arm that keeps the grammar honest: the consumer
# writes entries bold and backticked, so a grammar that only spells the plain form
# misses 10 of the 12 revisions carrying the bold one.
seed_entries '' '- **2026-09-12T02:53Z** bold misfile
1. `2026-09-12T02:54Z` ordered and backticked misfile
* 2026-09-12T02:55Z star-bulleted misfile' '- 2026-09-12T03:00Z: belongs here' 'none' '- none'
run_validator >/dev/null
if [ "$(entry_rows_for 'Sprint Context')" = "3" ]; then
  ok "ENTRY: bold, backticked, ordered and star-bulleted misfiles are all caught"
else
  bad "ENTRY: only $(entry_rows_for 'Sprint Context') of 3 decorated misfiles were caught"
fi

# --- E8. A DECLARED EXTRA SECTION IS OUT OF SCOPE ------------------------------
# A project that names its own section owns what goes under it; core does not know
# what belongs beneath a heading core does not define.
seed_entries '' '- sprint_id: 311' '- 2026-09-12T03:00Z: belongs here' 'none' '- none'
printf '## Deploy Baseline\n- 2026-09-12T06:00Z: the project owns this shape\n\n' >> "$SNAP"
got="$(AI_DLC_SNAPSHOT_EXTRA_SECTIONS='Deploy Baseline' run_validator)"
if [ "$(entry_rows_for 'Deploy Baseline')" = "0" ] && [ "$got" = "0" ]; then
  ok "ENTRY: a DECLARED extra section is out of scope for the entry arm"
else
  bad "ENTRY: a declared section's own content was indicted -- exit $got"
fi

# --- E9. ONE LINE REACHES verdict.sh, AND THE BUDGET SUMMARY SURVIVES ----------
# verdict.sh surfaces at most AI_DLC_VERDICT_LINES matching lines after `PASS <name>`,
# and that window is what gate-validation.md Check 14 pastes into its evidence cell.
# One WARN per misfiled line fills it and pushes the budget summary out of the
# verdict entirely -- so the arm emits ONE aggregate line and the detail rows are
# deliberately unmatchable by that grammar. This drives the REAL verdict.sh.
VERDICT=""
for cand in "$ROOT/core/scripts/verdict.sh" "$ROOT/scripts/ai-dlc/verdict.sh"; do
  [ -f "$cand" ] && VERDICT="$cand" && break
done
if [ -z "$VERDICT" ]; then
  bad "ENTRY: verdict.sh not found in either layout -- the surfacing arm cannot run"
else
  { printf '# Pipeline Snapshot\n\n## Pipeline Position\n- v: c\n\n## Sprint Context\n'
    i=1
    while [ "$i" -le 12 ]; do printf -- '- 2026-09-%02dT0%d:00Z: misfiled entry %d\n' "$i" $((i % 10)) "$i"; i=$((i+1)); done
    printf '\n## Recent Activity\n- 2026-09-01T00:00Z: belongs here\n\n'
    printf '## Open Items\nnone\n\n## Locked Decisions\nnone\n\n'
    printf '## In-Flight Teammates\nnone\n\n## Context Reminders\n- none\n\n'
  } > "$SNAP"
  ( cd "$WORK" && AI_DLC_PROJECT_ROOT="$WORK" bash "$VERDICT" validate-artifact-budget --only pipeline-snapshot.md ) \
    > "$WORK/verdict.txt" 2>&1
  v_status=$?
  v_summary="$(grep -c 'every measured living artifact is within its Rule 25(d) budget' "$WORK/verdict.txt")" || v_summary=0
  v_warn="$(grep -c 'dated activity entr' "$WORK/verdict.txt")" || v_warn=0
  if [ "$v_summary" -ge 1 ] && [ "$v_warn" = "1" ] && [ "$v_status" = "0" ]; then
    ok "ENTRY: through verdict.sh, 12 misfiles render as ONE line and the budget summary SURVIVES"
  else
    bad "ENTRY: verdict.sh rendered summary=$v_summary misfile-lines=$v_warn status=$v_status -- the evidence cell is crowded"
    sed 's/^/        /' "$WORK/verdict.txt" >&2
  fi
  # The detail rows must still be READABLE somewhere, or the aggregate is all a lead gets.
  run_validator >/dev/null
  if [ "$(entry_rows_for 'Sprint Context')" = "12" ]; then
    ok "  and all 12 detail rows are present in the validator's own output"
  else
    ok_n="$(entry_rows_for 'Sprint Context')"
    bad "  only $ok_n of 12 detail rows reached the output -- the list is silently truncated"
  fi
fi

# --- E10. THE MUTANTS ----------------------------------------------------------
# An absence-shaped WARN needs mutants: an arm that reports nothing has the same
# exit code as one that works, on every input, and nothing downstream reads it.
# Each mutant is a COPY, cmp -s-guarded, and each must fail only its own property.
mut() { # mut <name> <awk-program>; echoes the mutant path or empty
  _m="$WORK/mut-$1.sh"
  awk "$2" "$VALIDATOR" > "$_m" 2>/dev/null || { echo ""; return; }
  if cmp -s "$VALIDATOR" "$_m"; then echo ""; return; fi
  echo "$_m"
}

# M-E1: the arm reports nothing at all (the silent-death case).
M="$(mut dead '/printf "SEC\\t%s\\t      misfiled/ { next } { print }')"
if [ -z "$M" ]; then
  bad "MUTANT dead: DID NOT APPLY -- the report line was renamed; re-anchor this mutation"
else
  seed_entries '' '- 2026-09-12T02:53Z: routed fresh' '- 2026-09-12T03:00Z: belongs here' 'none' '- none'
  m_status="$(run_validator "$M")"
  if [ "$(entry_warn_count)" = "0" ]; then
    ok "MUTANT dead: killed -- E1 goes silent when the arm cannot report"
  else
    bad "MUTANT dead: SURVIVED -- E1 passes against an arm that reports nothing"
  fi
  # THE SELF-PROBE IS WHAT MAKES THIS MUTANT LOUD, and that is the property under
  # test. A silent arm is invisible to every exit code the corpus can produce --
  # this WARN never writes RC, so nothing downstream would notice. The probe runs
  # before the corpus, on a seeded offender, and refuses. Without it this mutant
  # would exit 0 and E1 would be the only thing between it and a green suite.
  if [ "$m_status" = "1" ] && grep -q 'self-probe' "$WORK/out.txt"; then
    ok "  and the SELF-PROBE refused the silent arm (exit 1) rather than letting it run quiet"
  else
    bad "  the silent arm was not refused by the self-probe (exit $m_status) -- a dead arm would ship green"
  fi
fi

# THE TWO WIDENINGS ARE INDEPENDENT, AND EACH NEEDS ITS OWN MUTANT.
# The grammar has two separate narrowings and they catch different things:
#   the BULLET requirement  excludes unbulleted wrapped prose (In-Flight, E5)
#   the TIMESTAMP `^`       excludes mid-line stamps (Pipeline Position, E3)
# Dropping the bullet does NOT admit a mid-line stamp and vice versa -- measured,
# by building both. One mutant covering "the anchor" would kill only one arm and
# leave the other proving nothing, which is exactly the silent-overlap failure.
#
# Each is scored TWICE: the self-probe refuses it before the corpus, and with the
# probe suppressed the corpus-side near-miss arm catches it. Scoring only the probe
# would make E3 and E5 vacuous the day the probe moves.
PROBE_OFF='/^\[ "\$PROBE_RC" -eq 0 \] \|\| exit 1$/ { next }'

# M-E2: the TIMESTAMP anchor dropped -- the line is searched anywhere (wrong fix b).
M="$(mut nostamp '{ sub(/if \(p !~ \/\^\[0-9\]/, "if ($0 !~ /[0-9]") } { print }')"
if [ -z "$M" ]; then
  bad "MUTANT nostamp: DID NOT APPLY -- the timestamp test was rewritten; re-anchor this mutation"
else
  seed_entries '- last_gate_passed: planning at 2026-09-12T22:14:00Z' '- sprint_id: 311' '- 2026-09-12T03:00Z: belongs here' 'none' '- none'
  m_status="$(run_validator "$M")"
  if [ "$m_status" = "1" ] && grep -q 'NEAR-MISS fired on a MID-line' "$WORK/out.txt"; then
    ok "MUTANT nostamp: killed by the self-probe -- a mid-line stamp is refused before the corpus"
  else
    bad "MUTANT nostamp: the self-probe did not refuse an unanchored timestamp (exit $m_status)"
  fi
  M2="$(mut nostamp-noprobe "{ sub(/if \(p !~ \/\^\[0-9\]/, \"if (\$0 !~ /[0-9]\") } $PROBE_OFF { print }")"
  if [ -z "$M2" ]; then
    bad "MUTANT nostamp: the probe-suppressing variant DID NOT APPLY -- re-anchor it"
  else
    run_validator "$M2" >/dev/null
    if [ "$(entry_rows_for 'Pipeline Position')" -ge 1 ]; then
      ok "  and E3's near-miss fires on the corpus too, with the probe out of the way"
    else
      bad "  E3's near-miss does NOT fire on an unanchored timestamp -- that arm proves nothing"
    fi
  fi
fi

# M-E2b: the BULLET requirement dropped -- wrapped prose becomes an entry.
M="$(mut nobullet '/blank:\]\]\+\/\) next/ { next } { print }')"
if [ -z "$M" ]; then
  bad "MUTANT nobullet: DID NOT APPLY -- the bullet guard was rewritten; re-anchor this mutation"
else
  seed_entries '' '- sprint_id: 311' '- 2026-09-12T03:00Z: belongs here' \
    '2026-09-09T14:05:45Z; a wrapped prose continuation, not a row' '- none'
  m_status="$(run_validator "$M")"
  if [ "$m_status" = "1" ] && grep -q 'NEAR-MISS fired on an UNBULLETED' "$WORK/out.txt"; then
    ok "MUTANT nobullet: killed by the self-probe -- unbulleted prose is refused before the corpus"
  else
    bad "MUTANT nobullet: the self-probe did not refuse a grammar with no bullet requirement (exit $m_status)"
  fi
  M2="$(mut nobullet-noprobe "/blank:\]\]\+\/\) next/ { next } $PROBE_OFF { print }")"
  if [ -z "$M2" ]; then
    bad "MUTANT nobullet: the probe-suppressing variant DID NOT APPLY -- re-anchor it"
  else
    run_validator "$M2" >/dev/null
    if [ "$(entry_rows_for 'In-Flight Teammates')" -ge 1 ]; then
      ok "  and E5's near-miss fires on the corpus too, with the probe out of the way"
    else
      bad "  E5's near-miss does NOT fire on an unbulleted line -- that arm proves nothing"
    fi
  fi
fi

# M-E3: the WARN promoted to a FAIL (the "block the gate" wrong fix).
M="$(mut blocking '/^  echo "WARN: pipeline-snapshot.md files \$\{ENTRY_N\}/ { print; print "  RC=1"; next } { print }')"
if [ -z "$M" ]; then
  bad "MUTANT blocking: DID NOT APPLY -- the WARN emitter was rewritten; re-anchor this mutation"
else
  seed_entries '' '- 2026-09-12T02:53Z: routed fresh' '- 2026-09-12T03:00Z: belongs here' 'none' '- none'
  m_status="$(run_validator "$M")"
  if [ "$m_status" = "1" ]; then
    ok "MUTANT blocking: killed -- E2 catches the finding being promoted to a failure"
  else
    bad "MUTANT blocking: SURVIVED (exit $m_status) -- E2 cannot see a WARN becoming a FAIL"
  fi
fi

# M-E4: UNMUTATED CONTROL, and it is PRESENCE-shaped. Two inert runs compare equal,
# so this asserts a specific row APPEARS rather than that nothing went wrong.
seed_entries '' '- 2026-09-12T02:53Z: routed fresh' '- 2026-09-12T03:00Z: belongs here' 'none' '- none'
ctrl_status="$(run_validator)"
if [ "$ctrl_status" = "0" ] && [ "$(entry_warn_count)" = "1" ] && [ "$(entry_rows_for 'Sprint Context')" = "1" ]; then
  ok "CONTROL: the UNMUTATED validator reports the offender and exits 0 (the mutants above ran against a working subject)"
else
  bad "CONTROL: the unmutated validator did not produce the baseline row -- every mutant verdict above is void"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "snapshot-section-schema: PASS"
  exit 0
fi
echo "snapshot-section-schema: FAIL ($fails assertion(s))"
exit 1
