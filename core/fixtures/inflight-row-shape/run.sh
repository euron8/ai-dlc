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
# THE SECOND DEFECT: THE STATUS TOKEN ITSELF (assertions 4b-4e, 5b).
#
# The column was `in-flight` or `idle-reusable`, and nothing anywhere enforced
# either spelling -- the token lived in prose in four core files and in a
# remediation string here. `idle-reusable` also named the wrong thing: the
# section, by gate-validation.md's own words, "records only whether the lead can
# still reach it", while the token advertised REUSE and bounded it by nothing.
# Rule 28 now bounds what a message to a reachable teammate may carry, and the
# token was renamed to `delivered-reachable` to state the fact rather than invite
# the reuse. A rename with no mechanism drifts back, so the set is closed here.
#
# The snapshots below are deliberately TINY. Every red must come from the In-Flight
# checks, never from the byte budget. Assertions 5 and 5b prove it.

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

# --- 1. Both status tokens pass ------------------------------------------------
# The state the column exists to express. A teammate that has delivered but is
# still reachable is a row, not history -- and must not need a strikethrough to
# say so, or the whole change is decorative.
seed "$HEADER
| \`dev-s296-story-2\` | \`dev\` | docs/reviews/x.md | 2026-07-22 | in-flight |
| \`qa-s296-story-1\` | \`qa\` | docs/reviews/y.md | 2026-07-22 | delivered-reachable |"
expect 0 "in-flight and delivered-reachable rows both pass"

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

# --- 4b. AN UNRECOGNISED STATUS TOKEN IS REFUSED, AND NAMED --------------------
# The column is a closed set of two. `idle-reusable` is the token the set was
# renamed AWAY from, so this doubles as the migration signal: a consumer whose
# snapshot still carries it is told, by the check, exactly which row to relabel.
seed "$HEADER
| \`qa-s296-story-1\` | \`qa\` | docs/reviews/y.md | 2026-07-22 | idle-reusable |"
expect 1 "an unrecognised status token is refused"
if grep -q 'qa-s296-story-1' "$WORK/out.txt"; then
  ok "  and the offending row is named in the output"
else
  bad "  the offending row is NOT named -- lead cannot act on this verdict"
fi
# Its own verdict, not the struck-row one. They route to OPPOSITE remedies:
# `struck row` says delete, `unknown status` says keep and relabel. Folded
# together, a lead deletes the row it was supposed to fix.
if grep -q 'unrecognised status' "$WORK/out.txt" && ! grep -q 'struck-through row' "$WORK/out.txt"; then
  ok "  and it is a separate verdict from the struck-row check"
else
  bad "  folded into the struck-row verdict -- opposite remedy for the lead"
fi

# --- 4c. A TRAILING NOTE AFTER THE TOKEN PASSES --------------------------------
# Pins the measured PREFIX decision. The reference consumer's live snapshot
# carries `in-flight, retrying Write` and `in-flight, since <ts>`; an equality
# check would have failed two of its three real rows on the day it shipped. If
# this assertion ever goes red, the check was silently tightened to equality.
seed "$HEADER
| \`a-1\` | \`analyst\` | docs/x.md | 2026-07-22 | in-flight, retrying Write |
| \`a-2\` | \`analyst\` | docs/y.md | 2026-07-22 | delivered-reachable, appending |"
expect 0 "a trailing note after the status token still passes"

# The delimiter is whitespace too, not only punctuation. This exact shape is what
# the live reference snapshot carries, and it is what a comma-only split failed
# during development -- the measurement caught it, so it is pinned here.
seed "$HEADER
| \`a-3\` | \`adversary\` | docs/z.md | 2026-07-22 | in-flight (VERIFY pass, \`resolves: x.md\`) |"
expect 0 "a space-delimited trailing note still passes"

# --- 4d-legacy. A TABLE THAT DECLARES NO STATUS COLUMN IS NOT CHECKED ----------
# Measured across the reference consumer's 151 snapshots: four archives predate
# the five-column row and declare `| teammate | deliverable | dispatched-at |
# state |`. Their last cell is a timestamp or a deliverable, and indicting it
# would be the check reading a column that does not exist. The scan arms on the
# header declaring `status`, which is derived from the table, not an exception
# list. If this goes red, the check started inventing a column.
seed "| teammate | deliverable | dispatched-at | state |
|---|---|---|---|
| \`analyst-s295\` | docs/x.md | 2026-07-21T12:50Z | delivered |"
expect 0 "a legacy table with no status column raises no status finding"

# --- 4d. THE EMPTY-TABLE FORM route.md CREATES PASSES ---------------------------
# Assertion 4 already covers this for the struck check; it is repeated here
# because the status check parses cells the struck check never looked at, and the
# header row's own last cell is the literal word `status`. A check that indicts
# the schema route.md writes is a check no consumer can start a pipeline with.
seed "$HEADER"
expect 0 "the header+separator form carries no status finding"

# --- 4e. A STRUCK ROW RAISES EXACTLY ONE VERDICT -------------------------------
# Struck rows carry a dash in the status cell, so without the strikethrough
# exemption every struck-row assertion above would ALSO be a status assertion and
# neither would prove anything alone. This is the isolation check for that.
seed "$HEADER
| ~~\`dev-s296-story-1\`~~ | \`dev-escalated\` | DELIVERED + CONSUMED | 2026-07-22 | — |"
run_validator >/dev/null
if grep -q 'unrecognised status' "$WORK/out.txt"; then
  bad "  a struck row also tripped the status check -- the two checks are entangled"
else
  ok "a struck row raises the struck verdict only, not the status one"
fi

# --- 4f. `stopped` IS ACCEPTED, BESIDE A TOKEN THAT IS NOT ---------------------
# THE THIRD TOKEN, AND THE ARM IS DELIBERATELY NOT "a stopped row exits 0".
# That shape is absence-shaped: it passes identically against a subject replaced
# by `exit 0`, and the status check would then be dead with this arm still green.
# So the accepted row sits BESIDE a genuinely unrecognised one in the SAME run,
# and the assertions are PRESENCE-shaped -- the offender must be NAMED and the
# stopped row must NOT be. A subject that emits nothing fails the first conjunct;
# the pre-fix two-token whitelist fails the second, because it names both.
#
# The seed is the form the reference consumer actually wrote at sprint 308 --
# `stopped (operator-requested handoff)` -- not a form derived from the reader's
# accept-set. Its trailing note also re-exercises the space delimiter 4c pins.
seed "$HEADER
| \`stopped-s308-alpha\` | \`adversary\` | docs/x.md | 2026-09-02 | stopped (operator-requested handoff) |
| \`unknown-s308-beta\` | \`qa\` | docs/y.md | 2026-09-02 | idle-reusable |"
expect 1 "an unrecognised token beside a stopped row still fails"
if grep -q 'unknown-s308-beta' "$WORK/out.txt"; then
  ok "  and the unrecognised row is named"
else
  bad "  the unrecognised row is NOT named -- the check is not reading this table"
fi
if grep -q 'stopped-s308-alpha' "$WORK/out.txt"; then
  bad "  the stopped row was ALSO indicted -- handoff.md step 1 cannot be obeyed"
else
  ok "  and the stopped row is not indicted (steps/handoff.md step 1 is obeyable)"
fi

# --- 4g. A STRUCK `stopped` ROW RAISES THE STRUCK VERDICT ONLY -----------------
# 4e pins this for the dash cell. It is repeated for `stopped` because adding a
# third token is exactly the change that invites a later hand to revisit the
# `/~~/ next` exemption at the top of check_inflight_status -- and if that
# exemption goes, a struck stopped row draws BOTH verdicts, whose remedies are
# opposite: struck says DELETE, unknown-status says KEEP AND RELABEL. A lead
# handed both deletes the row it was told to fix.
seed "$HEADER
| \`struck-s308\` | \`adversary\` | docs/x.md | 2026-09-02 | ~~stopped~~ |"
expect 1 "a struck 'stopped' row is refused"
if grep -q 'struck-through row' "$WORK/out.txt" && ! grep -q 'unrecognised status' "$WORK/out.txt"; then
  ok "  and it raises the struck verdict ONLY, not the status one"
else
  bad "  both verdicts fired on one row -- opposite remedies, and the lead deletes what it should relabel"
fi

# --- 4h. THE COMMA FORM OF `stopped` -------------------------------------------
# The remedy text this check prints advertises `stopped, operator-requested
# handoff`. 4c pins the comma delimiter for `in-flight` only, so without this arm
# the form the check RECOMMENDS is the one form never exercised. Both delimiters
# are asserted here beside a genuine offender, so the arm stays presence-shaped.
seed "$HEADER
| \`comma-s308\` | \`adversary\` | docs/x.md | 2026-09-02 | stopped, operator-requested handoff |
| \`space-s308\` | \`adversary\` | docs/y.md | 2026-09-02 | stopped (operator-requested handoff) |
| \`unk-s308\` | \`qa\` | docs/z.md | 2026-09-02 | idle-reusable |"
expect 1 "an unrecognised token beside both 'stopped' delimiter forms still fails"
if grep -q 'unk-s308' "$WORK/out.txt"; then
  ok "  and the unrecognised row is named"
else
  bad "  the unrecognised row is NOT named -- the check is not reading this table"
fi
if grep -q 'comma-s308' "$WORK/out.txt" || grep -q 'space-s308' "$WORK/out.txt"; then
  bad "  a 'stopped' row was indicted -- the remedy text advertises a form the check rejects"
else
  ok "  and neither 'stopped' form is indicted (the printed remedy is followable)"
fi

# --- 4i-4l. THE PIPELESS ROW SHAPE ---------------------------------------------
#
# WHY EVERY ARM ABOVE THIS LINE IS A CONTROL AND NONE OF THEM IS A TEST OF THIS.
# Derived over this file at the commit these arms were added: 22 seeded row lines,
# 22 of them carrying a leading `|`, 0 pipeless. Markdown renders a table row with
# or without the opening delimiter and the reference consumer writes the bare form,
# so `check_inflight_status`'s `/^[[:space:]]*\|/` gate admitted 0 of that
# consumer's rows against a control of 2 on the piped shape in the same invocation.
# The check could not fail because no seed here carried the discriminating shape --
# which is a gap in the SEED, not a missing arm, and a twenty-third piped seed would
# not have found it.
#
# THE PIPELESS HEADER IS ITS OWN STRING AND DOES NOT TOUCH $HEADER. Every arm above
# builds from that constant and they must keep passing byte-unchanged; they are the
# evidence that the relaxation lost nothing.
#
# THE SEED IS THE PRODUCER'S SHAPE, NOT THE READER'S. No leading pipe, no trailing
# pipe, no `|---|` separator, no backticks -- what the consumer writes, verbatim,
# down to the `dispatched (fix-forward)` token that motivated the fix and is outside
# the closed set of three declared above check_inflight_status.
PHEADER='agent | role | deliverable | dispatched-at | status'
PROW_BAD='a2b2344be58b99e31 | dev-escalated | /abs/path/report.md | 2026-09-14T04:20:00Z | dispatched (fix-forward)'
PROW_OK='b7c1f0e2d3a4b5c69 | qa | /abs/path/qa.md | 2026-09-14T04:20:00Z | in-flight, since 2026-09-14T04:20:00Z'

# 4i. PIPELESS + ILLEGAL beside PIPELESS + LEGAL, in ONE run.
# Two cells of the matrix, and the pairing is what makes them readable: the
# assertions are PRESENCE-shaped -- the illegal row must be NAMED and the legal one
# must NOT be -- so a subject that emits nothing fails the first conjunct instead of
# scoring the second. A pipeless seed alone would prove only that something
# happened; the legal twin is what says the relaxation discriminates.
seed "$PHEADER
$PROW_BAD
$PROW_OK"
expect 1 "a PIPELESS row with an illegal token is refused (the arm that was dead)"
if grep -q 'a2b2344be58b99e31' "$WORK/out.txt"; then
  ok "  and the pipeless offender is named in the output"
else
  bad "  the pipeless offender is NOT named -- the check still cannot see a bare row"
fi
if grep -q 'b7c1f0e2d3a4b5c69' "$WORK/out.txt"; then
  bad "  the LEGAL pipeless row was also indicted -- the relaxation convicts on shape, not on token"
else
  ok "  and the legal pipeless row beside it is not indicted"
fi
if grep -q 'over the Rule 25(d) budget' "$WORK/out.txt"; then
  bad "  CONFOUNDED: the byte budget also fired -- exit 1 proves nothing here"
else
  ok "  and the byte budget stayed quiet (the red is the In-Flight check's alone)"
fi

# 4j. PIPELESS + LEGAL ALONE -> PASS.
# The near-miss direction on its own. 4i's pairing shows the legal row is not NAMED;
# this shows the run does not go red at all, which is the claim a wrong fix that
# convicted every pipeless line would break. No mutant below kills this arm and that
# is stated rather than papered over -- it is a both-directions control, and 4i and
# 4k are what carry the mutants.
seed "$PHEADER
$PROW_OK"
expect 0 "a PIPELESS row with a legal token passes (the relaxation did not convict everything)"

# 4k. PIPED + ILLEGAL beside PIPED + LEGAL -> unchanged behaviour.
# The other two cells. These are what the gate already did; they are here so the
# matrix is a matrix, and so a mutant that moves the piped path is visible as an
# entanglement rather than as a pipeless finding.
seed "$HEADER
| \`piped-bad-s105\` | \`dev-escalated\` | docs/x.md | 2026-09-14 | dispatched (fix-forward) |
| \`piped-ok-s105\` | \`qa\` | docs/y.md | 2026-09-14 | in-flight, since 2026-09-14T04:20:00Z |"
expect 1 "a PIPED row with an illegal token is still refused (existing behaviour)"
if grep -q 'piped-bad-s105' "$WORK/out.txt"; then
  ok "  and the piped offender is named"
else
  bad "  the piped offender is NOT named -- the relaxation LOST a finding the gate had"
fi
if grep -q 'piped-ok-s105' "$WORK/out.txt"; then
  bad "  the legal piped row was also indicted -- existing behaviour regressed"
else
  ok "  and the legal piped row beside it is not indicted (existing behaviour)"
fi

# 4l. THE PIPELESS HEADER IS NEVER SCORED AS A DATA ROW.
# The header carries no leading pipe either, and its last cell is the literal word
# `status`, which is not a member of the closed set. A relaxation that lets it fall
# through indicts the schema route.md writes -- a check no consumer can start a
# pipeline with. Seeded ALONE, so nothing else in the section can produce the zero.
seed "$PHEADER"
expect 0 "a PIPELESS header with no data rows raises no status finding"
if grep -q 'INFLIGHT' "$WORK/out.txt"; then
  bad "  the pipeless header itself was reported -- route.md's own schema is indicted"
else
  ok "  and nothing at all is reported for it"
fi

# 4m. PROSE CARRYING A PIPE IS NOT A ROW.
# THIS IS THE MEASURED FALSE POSITIVE, and it is why a bare `/\|/` gate is the wrong
# fix rather than a simpler one. Over the reference consumer's In-Flight-bearing
# files the bare form reported 4 findings the gate did not, and one was an archived
# note ending in a shell fragment -- its last pipe-delimited field is `wc -l`, which
# is outside the closed set and reads to a token check as an illegal status.
# A line with no leading `|` must therefore also carry the column count the HEADER
# declares. Seeded beside a legal row so the section is the shape a real one is.
#
# THE IDENTIFYING TOKEN LEADS THE LINE, AND THAT IS NOT COSMETIC. The check prints
# `cut -c1-70` of whatever it indicts, so a grep keyed on the line's TAIL -- on
# `wc -l`, the natural choice -- cannot fire: the truncation removes it, and the arm
# reads green against a subject that IS convicting the prose. Measured here, by
# mutant 5g's sibling below, which reported SURVIVED against a mutant that names the
# line. Key on a token inside the first 70 bytes.
seed "$PHEADER
$PROW_OK
prose-s105 note: the branch is ahead by \`git log @{u}..HEAD --oneline | wc -l\` commits."
expect 0 "prose carrying a pipe is not admitted as a row"
if grep -q 'prose-s105' "$WORK/out.txt"; then
  bad "  the prose line was reported as an unknown status -- the measured false positive is back"
else
  ok "  and the prose line is not reported (the header-width narrowing holds)"
fi

# 4n. A STRAY `|` INSIDE A CELL OF A PIPED ROW IS STILL CONVICTED.
# THE ARM THAT KILLS THE MOST PLAUSIBLE WRONG FIX. Applying the header-width test to
# EVERY row rather than only to pipeless ones is the obvious simplification and it
# is a REGRESSION: a piped row whose cell contains a `|` splits one field wide, fails
# the width test, and is acquitted -- a finding the pre-fix gate already produced.
# Both illegal rows are seeded in ONE run and both must be named; the uniform form
# names exactly one.
seed "$HEADER
| \`stray-s105\` | \`qa\` | docs/x|y.md | 2026-09-14 | dispatched (fix-forward) |
| \`plain-s105\` | \`qa\` | docs/z.md | 2026-09-14 | dispatched (fix-forward) |"
expect 1 "a piped row with a stray pipe inside a cell still fails"
if grep -q 'stray-s105' "$WORK/out.txt"; then
  ok "  and the stray-pipe row is named (the width test did not leak onto piped rows)"
else
  bad "  the stray-pipe row was ACQUITTED -- the width test was applied uniformly and a finding the gate had is lost"
fi
if grep -q 'plain-s105' "$WORK/out.txt"; then
  ok "  and the ordinary piped offender beside it is named too"
else
  bad "  the ordinary piped offender is NOT named either -- the check is not reading this table"
fi

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

# --- 5b. THE MUTATION TEST for the status check --------------------------------
# Same shape, built as a COPY with a matched-nothing guard. The CONTROL below is
# not optional: a lone script copy that dies for its own reasons emits nothing
# and exits non-zero, which is indistinguishable from the check firing, so the
# unmutated copy has to be shown alive on the same input first.
CONTROL="$WORK/control.sh"
cp "$VALIDATOR" "$CONTROL" || exit 2
SMUTANT="$WORK/mutant-status.sh"
sed '/check_inflight_status "\$f" "\$rel"/d' "$VALIDATOR" > "$SMUTANT" || exit 2
if cmp -s "$VALIDATOR" "$SMUTANT"; then
  echo "FIXTURE ERROR: status mutation matched nothing -- the call site was renamed" >&2
  echo "  update the sed pattern in assertion 5b to match the real call" >&2
  exit 2
fi
seed "$HEADER
| \`qa-s296-story-1\` | \`qa\` | docs/reviews/y.md | 2026-07-22 | idle-reusable |"
control_status="$(run_validator "$CONTROL")"
if [ "$control_status" = "1" ]; then
  ok "CONTROL: an unmutated copy still refuses the unrecognised token"
else
  bad "CONTROL: unmutated copy exited $control_status -- the copy is broken, 5b proves nothing"
fi
smutant_status="$(run_validator "$SMUTANT")"
if [ "$smutant_status" = "0" ]; then
  ok "MUTATION: removing the status check makes assertion 4b go green"
else
  bad "MUTATION: assertion 4b still fails (exit $smutant_status) without the check -- it proves nothing"
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

# --- 5c. THE MUTATION TEST for the third token ---------------------------------
# 4f establishes that the stopped row is not indicted. Only a mutant establishes
# that the whitelist entry is what stops it: an arm reading "this row was not
# named" is satisfied by a check that names nothing at all.
#
# Three readings, and the first is not optional. A lone copy that dies for its
# own reasons emits nothing and exits non-zero, which is indistinguishable from
# the check firing -- so the unmutated copy is shown ALIVE on a presence-shaped
# input first, then quiet on the stopped row, and only then is the mutant's red
# attributable to the missing whitelist line.
TMUTANT="$WORK/mutant-stopped.sh"
sed '/if (tok == "stopped") next/d' "$VALIDATOR" > "$TMUTANT" || exit 2
if cmp -s "$VALIDATOR" "$TMUTANT"; then
  echo "FIXTURE ERROR: stopped-token mutation matched nothing -- the whitelist" >&2
  echo "  entry was reworded; re-anchor assertion 5c on the real line" >&2
  exit 2
fi
STOPPED_ROW="$HEADER
| \`stopped-s308-alpha\` | \`adversary\` | docs/x.md | 2026-09-02 | stopped (operator-requested handoff) |"

seed "$HEADER
| \`unknown-s308-beta\` | \`qa\` | docs/y.md | 2026-09-02 | idle-reusable |"
alive_status="$(run_validator "$CONTROL")"
if [ "$alive_status" = "1" ] && grep -q 'unknown-s308-beta' "$WORK/out.txt"; then
  ok "CONTROL: the unmutated copy is alive (it still names an unrecognised token)"
else
  bad "CONTROL: unmutated copy exited $alive_status without naming the row -- 5c proves nothing"
fi

seed "$STOPPED_ROW"
base_status="$(run_validator "$CONTROL")"
if [ "$base_status" = "0" ]; then
  ok "CONTROL: the same live copy accepts the stopped row"
else
  bad "CONTROL: the unmutated copy rejected the stopped row (exit $base_status)"
fi

tmutant_status="$(run_validator "$TMUTANT")"
if [ "$tmutant_status" = "1" ] && grep -q 'stopped-s308-alpha' "$WORK/out.txt"; then
  ok "MUTATION: removing the stopped entry indicts the stopped row again"
else
  bad "MUTATION: without the whitelist entry the stopped row exited $tmutant_status unnamed -- 4f proves nothing"
fi

# --- 5d-5g. THE MUTANTS FOR THE PIPELESS ARMS ----------------------------------
#
# Four mutants, each keyed on a LOCATION and scored on an OBSERVABLE BEHAVIOUR --
# which row the check names -- never on a spelling in the output. Each is built as a
# COPY, guarded by `cmp -s` so a `sed` that matched nothing reports FIXTURE STALE
# rather than scoring a kill, and every arm is PRESENCE-shaped: a copy that died on
# load emits nothing and exits non-zero, which is indistinguishable from the check
# firing, so the kill is read off a NAMED ROW and not off an exit code.
#
# $CONTROL, the unmutated copy from 5b, is already shown alive above -- it names
# `unknown-s308-beta` on a presence-shaped input. It is re-shown alive on each
# PIPELESS input here, because being alive on the piped shape is exactly the
# property the defect had.
#
# WHAT EACH ONE KILLS, and each kills exactly one wrong implementation:
#   5d  the pre-fix gate            -> 4i goes red  (pipeless rows unreachable)
#   5e  the bare `/\|/` fix         -> 4m goes red  (prose convicted)
#   5f  the uniform width test      -> 4n goes red  (stray-pipe row acquitted)
#   5g  ncols from the first row    -> 4i goes red  (width taken from a data row)
mut_copy() { # mut_copy <dest> <sed-expr> <label>
  sed "$2" "$VALIDATOR" > "$1" || { bad "MUTANT $3: sed DIED -- the mutation never existed"; return 1; }
  if cmp -s "$VALIDATOR" "$1"; then
    bad "FIXTURE STALE: mutation $3 matched nothing in $VALIDATOR -- re-anchor it on the real line"
    return 1
  fi
  return 0
}

# 5d. REVERT THE GATE to the leading-pipe form. This is the pre-fix program.
D_MUT="$WORK/mutant-gate.sh"
# TWO BSD-sed traps, both of which produce a mutant that APPLIES and is WRONG, which
# `cmp -s` cannot see.
#
# First, `|` cannot be this expression's delimiter: the anchor line carries one, BSD
# sed reads it as the separator and reports `bad flag in substitute command`. `%` is
# the delimiter, and the anchor is the trailing COMMENT -- the only thing separating
# this line from every other `!`-guarded awk rule in the file.
#
# Second, THE BACKSLASH IN THE REPLACEMENT MUST BE DOUBLED. A single `\|` is consumed
# by sed and the mutant lands as `/^[[:space:]]*|/`, which in awk is an ALTERNATION of
# two empty branches: it matches every line, so `!` skips every line and the check
# indicts NOTHING. That mutant kills every arm at once, which reads as a successful
# revert and is a dead program. Measured: it took 4k and 4n down with 4i. The arm
# below asserts the escape survived, byte-wise, before any verdict is read.
if mut_copy "$D_MUT" 's%^    !.*# prose, %    !/^[[:space:]]*\\|/                { next }        # MUTANT pre-fix gate: %' "5d"; then
  if grep -qF '!/^[[:space:]]*\|/' "$D_MUT"; then
    ok "MUTANT 5d applied with its escape intact (not the match-everything alternation)"
  else
    bad "MUTANT 5d LOST ITS BACKSLASH -- the gate became an empty alternation matching every line, so the check indicts nothing and the kill below is a dead program, not a pre-fix revert"
  fi
  seed "$PHEADER
$PROW_BAD
$PROW_OK"
  d_ctl="$(run_validator "$CONTROL")"
  if [ "$d_ctl" = "1" ] && grep -q 'a2b2344be58b99e31' "$WORK/out.txt"; then
    ok "CONTROL: the unmutated copy names the pipeless offender on 4i's own input"
  else
    bad "CONTROL: the unmutated copy exited $d_ctl without naming the pipeless row -- 5d proves nothing"
  fi
  d_out="$(run_validator "$D_MUT")"
  if [ "$d_out" = "0" ]; then
    ok "MUTANT 5d: the pre-fix leading-pipe gate cannot see the pipeless row -- 4i goes green, so 4i is what tests the relaxation"
  else
    bad "MUTANT 5d SURVIVED: the leading-pipe gate still exited $d_out on a pipeless row -- either the seed is not pipeless or 4i is fed by something else"
  fi
  # ISOLATION. A mutant that fails more than its own assertion means one of them is
  # vacuous, and here it means something sharper: the pre-fix gate is the program that
  # ran in production, and it CONVICTED piped offenders. A 5d that also takes 4k down
  # is not a revert, it is a dead check -- exactly what the lost backslash produced.
  seed "$HEADER
| \`piped-bad-s105\` | \`dev-escalated\` | docs/x.md | 2026-09-14 | dispatched (fix-forward) |"
  d_piped="$(run_validator "$D_MUT")"
  if [ "$d_piped" = "1" ] && grep -q 'piped-bad-s105' "$WORK/out.txt"; then
    ok "  and 5d still names the PIPED offender -- it reverts the gate, it does not disable the check"
  else
    bad "  MUTANT 5d also killed the piped arm (exit $d_piped) -- it is a dead program, not the pre-fix gate, so its kill on 4i is unreadable"
  fi
fi

# 5e. DROP THE WIDTH TEST entirely, leaving the bare `/\|/` form.
# Scored on 4m's prose seed. The mutation deletes the one line that separates a
# pipeless ROW from a pipeless LINE, so the shell fragment's last field is read as a
# status token.
E_MUT="$WORK/mutant-nowidth.sh"
if mut_copy "$E_MUT" '/if (!piped \&\& n != ncols) next/d' "5e"; then
  seed "$PHEADER
$PROW_OK
prose-s105 note: the branch is ahead by \`git log @{u}..HEAD --oneline | wc -l\` commits."
  e_ctl="$(run_validator "$CONTROL")"
  if [ "$e_ctl" = "0" ]; then
    ok "CONTROL: the unmutated copy passes 4m's prose seed"
  else
    bad "CONTROL: the unmutated copy exited $e_ctl on 4m's prose seed -- 5e proves nothing"
  fi
  e_out="$(run_validator "$E_MUT")"
  if [ "$e_out" = "1" ] && grep -q 'prose-s105' "$WORK/out.txt"; then
    ok "MUTANT 5e: without the width test the prose line is convicted BY NAME -- 4m is what holds the measured false positive at zero"
  else
    bad "MUTANT 5e SURVIVED: the bare-pipe form exited $e_out without naming the prose line -- 4m's seed is not reaching the gate"
  fi
fi

# 5f. APPLY THE WIDTH TEST TO ALL ROWS, not only pipeless ones.
# The most plausible wrong fix: it is simpler, it passes 4i, 4j, 4l and 4m, and it
# silently drops a finding the PRE-fix gate already produced. Scored on 4n, where
# the stray-`|` row splits one field wide.
F_MUT="$WORK/mutant-uniform.sh"
if mut_copy "$F_MUT" 's|if (!piped \&\& n != ncols) next|if (n != ncols) next|' "5f"; then
  seed "$HEADER
| \`stray-s105\` | \`qa\` | docs/x|y.md | 2026-09-14 | dispatched (fix-forward) |
| \`plain-s105\` | \`qa\` | docs/z.md | 2026-09-14 | dispatched (fix-forward) |"
  f_ctl="$(run_validator "$CONTROL")"
  if [ "$f_ctl" = "1" ] && grep -q 'stray-s105' "$WORK/out.txt"; then
    ok "CONTROL: the unmutated copy names the stray-pipe row on 4n's own input"
  else
    bad "CONTROL: the unmutated copy exited $f_ctl without naming the stray-pipe row -- 5f proves nothing"
  fi
  f_out="$(run_validator "$F_MUT")"
  if grep -q 'stray-s105' "$WORK/out.txt"; then
    bad "MUTANT 5f SURVIVED: the uniform width test still named the stray-pipe row (exit $f_out) -- 4n cannot distinguish the two forms"
  elif grep -q 'plain-s105' "$WORK/out.txt"; then
    ok "MUTANT 5f: the uniform width test ACQUITS the stray-pipe row while still naming the ordinary one -- 4n is what keeps the relaxation a superset"
  else
    bad "MUTANT 5f: the copy named NEITHER row (exit $f_out) -- it is dead, not discriminating, and the kill is unreadable"
  fi
fi

# 5g. CAPTURE ncols FROM THE FIRST ROW instead of from the `status` header row.
# The width then comes from whatever pipe-bearing line appears first rather than
# from the table's own declaration. Scored on 4i: the mutation moves the `status`
# arm's recording to the pre-header default, so the pipeless data row is measured
# against a width nothing declared and falls through unchecked.
G_MUT="$WORK/mutant-firstrow.sh"
if mut_copy "$G_MUT" 's|{ declared = 1; ncols = n; next } # the header declares the column|{ declared = 1; next } # MUTANT: width not taken from the header|' "5g"; then
  seed "$PHEADER
$PROW_BAD
$PROW_OK"
  g_ctl="$(run_validator "$CONTROL")"
  if [ "$g_ctl" = "1" ] && grep -q 'a2b2344be58b99e31' "$WORK/out.txt"; then
    ok "CONTROL: the unmutated copy names the pipeless offender before 5g is read"
  else
    bad "CONTROL: the unmutated copy exited $g_ctl without naming the pipeless row -- 5g proves nothing"
  fi
  g_out="$(run_validator "$G_MUT")"
  if [ "$g_out" = "0" ]; then
    ok "MUTANT 5g: with ncols not taken from the header row the pipeless offender escapes -- 4i is bound to the DERIVED width, not to any width"
  else
    bad "MUTANT 5g SURVIVED: exit $g_out with the header's width recording deleted -- 4i passes under a width from somewhere else"
  fi
fi

# 5h. LET THE HEADER FALL THROUGH instead of exiting at the `status` arm.
# 4l is ABSENCE-shaped -- it asserts nothing is reported -- so it is the arm that
# REQUIRES a mutant rather than a near-miss: with the subject replaced by a program
# that emits nothing it would print `ok` forever. Removing the `next` leaves the
# header's own last cell, the literal word `status`, to reach the token test, where
# it is outside the closed set of three and is indicted BY ITS OWN TEXT.
H_MUT="$WORK/mutant-headerrow.sh"
if mut_copy "$H_MUT" 's|{ declared = 1; ncols = n; next } # the header declares the column|{ declared = 1; ncols = n } # MUTANT: header not exempted|' "5h"; then
  seed "$PHEADER"
  h_ctl="$(run_validator "$CONTROL")"
  if [ "$h_ctl" = "0" ]; then
    ok "CONTROL: the unmutated copy passes 4l's header-only seed"
  else
    bad "CONTROL: the unmutated copy exited $h_ctl on the pipeless header alone -- 5h proves nothing"
  fi
  h_out="$(run_validator "$H_MUT")"
  if [ "$h_out" = "1" ] && grep -q 'dispatched-at | status' "$WORK/out.txt"; then
    ok "MUTANT 5h: without its exemption the pipeless HEADER is itself indicted -- 4l is a real arm and not an absence that passes against a dead check"
  else
    bad "MUTANT 5h SURVIVED: exit $h_out with the header exemption removed and the header unnamed -- 4l would pass against a check that reports nothing"
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "inflight-row-shape: PASS"
  exit 0
fi
echo "inflight-row-shape: FAIL ($fails assertion(s))"
exit 1
