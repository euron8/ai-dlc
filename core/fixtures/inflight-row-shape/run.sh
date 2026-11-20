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
echo "HERMETIC-CONSUMED $VALIDATOR"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output" || exit 2
SNAP="$WORK/_bmad-output/pipeline-snapshot.md"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# IN PROCESS (BL-878). The validator is asked through vab_ip, which hands it to lib/inproc.sh's inproc_run: the file is
# loaded once here (inproc_load) and vab_main runs in a fresh-bash subshell, so its `exit` stays in that subshell. The
# program runs only in the cells of cells.decl (the cli cells below, each compared byte for byte with the in-process
# answer on the same input).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present subject with neither the `vab_main() {` line nor the column-0
# source guard predates the wrap, and sourcing it would run its whole body: SKIP and exit 0 (FIXTURE BROKEN in the
# distribution), never an ok. Exactly one half is a respelled subject this fixture cannot drive, which FAILS. An
# unreadable subject is FIXTURE ERROR.
# shellcheck source=/dev/null
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: lib/layout.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found" >&2; exit 2; }
vab_halves() { # vab_halves <file> -> "<def><guard>" (1 present, 0 absent); exit 2 on an unreadable file
  local d=0 g=0 x
  grep -qxF 'vab_main() {' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
_vh="$(vab_halves "$VALIDATOR")" || exit 2
case "$_vh" in
  11) : ;;
  00) echo "SKIP: inflight-row-shape: $VALIDATOR predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) bad "$VALIDATOR carries one half of the in-process wrap (vab_main line, column-0 source guard: $_vh) -- a respelled subject this fixture cannot drive"
     report_end inflight-row-shape ;;
esac
inproc_load "$VALIDATOR" || { echo "FIXTURE ERROR: could not load $VALIDATOR" >&2; exit 2; }
vab_ip() { inproc_run "$VALIDATOR" vab_main "$@"; }
# vab_eqv <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}: the in-process answer and the program's, for the cli cell.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq failed" >&2; exit 2; }
vab_eqv() {
  local id="$1"; shift
  vab_ip "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$VALIDATOR" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
# vab_cell <id> <want rc> <label> <args...>: the cli cell. PRESENCE-shaped: the program's rc is the wanted one, its
# stdout is non-empty (a subject replaced by `exit 0` fails), and all three streams equal the in-process call's.
vab_cell() {
  local id="$1" want="$2" label="$3"; shift 3
  if vab_eqv "$id" "$@" && [ "$(cat "$EQ/$id.cl.rc")" = "$want" ] && [ -s "$EQ/$id.cl.out" ]; then
    ok "$id: $label -- the program and the in-process call agree byte for byte, exit $want"
  else
    bad "$id: $label -- the program and the in-process call differ, or the exit is not $want (in-process rc=$(cat "$EQ/$id.ip.rc") / program rc=$(cat "$EQ/$id.cl.rc"))"
  fi
}

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
  vab_ip --root "$WORK" --only pipeline-snapshot.md >"$WORK/out.txt" 2>&1
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
# convicted every pipeless line would break. It is a both-directions control.
seed "$PHEADER
$PROW_OK"
expect 0 "a PIPELESS row with a legal token passes (the relaxation did not convict everything)"

# 4k. PIPED + ILLEGAL beside PIPED + LEGAL -> unchanged behaviour.
# The other two cells. These are what the gate already did; they are here so the
# matrix is a matrix, and so a change to the piped path is visible as an
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
# a mutant that named the prose line, which reported SURVIVED against it. Key on a
# token inside the first 70 bytes.
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

# --- 4o. EACH FAIL CARRIES ITS OWN LABELLED `Remedy:` LINE --------------------
# The two remedies are OPPOSITE (struck: DELETE the row; unknown status: KEEP it and
# relabel), so each is read from its OWN world and never from one combined stderr --
# a combined run would let either remedy satisfy either assertion. Every conjunct is
# PRESENCE-shaped (the remedy must APPEAR), and each world also asserts the OTHER
# verdict's remedy is absent, so a swap between the two heredocs is visible.
STRUCK_REMEDY='Remedy: DELETE each struck row'
STATUS_REMEDY='Remedy: KEEP the row'
# remedy_arms <validator> <label-prefix>: drives both worlds and scores four conjuncts.
remedy_arms() {
  local v="$1" p="$2"
  seed "$HEADER
| ~~\`dev-s296-story-1\`~~ | \`dev-escalated\` | DELIVERED + CONSUMED | 2026-07-22 | — |"
  run_validator "$v" >/dev/null
  if grep -q 'struck-through row' "$WORK/out.txt" && grep -qF "$STRUCK_REMEDY" "$WORK/out.txt"; then
    ok "${p}the struck-row FAIL carries its own Remedy line"
  else
    bad "${p}the struck-row FAIL carries no 'Remedy: DELETE each struck row' line"
  fi
  if grep -qF "$STATUS_REMEDY" "$WORK/out.txt"; then
    bad "${p}the struck-only world printed the unknown-status remedy -- the lead keeps what it should delete"
  else
    ok "${p}the struck-only world does not print the unknown-status remedy"
  fi
  seed "$HEADER
| \`qa-s296-story-1\` | \`qa\` | docs/reviews/y.md | 2026-07-22 | idle-reusable |"
  run_validator "$v" >/dev/null
  if grep -q 'unrecognised status' "$WORK/out.txt" && grep -qF "$STATUS_REMEDY" "$WORK/out.txt"; then
    ok "${p}the unknown-status FAIL carries its own Remedy line"
  else
    bad "${p}the unknown-status FAIL carries no 'Remedy: KEEP the row' line"
  fi
  if grep -qF "$STRUCK_REMEDY" "$WORK/out.txt"; then
    bad "${p}the unknown-status world printed the struck-row remedy -- the lead deletes what it should relabel"
  else
    ok "${p}the unknown-status world does not print the struck-row remedy"
  fi
}
remedy_arms "$VALIDATOR" ""

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
vab_ip --root "$WORK" --only pipeline-snapshot.md --warn-only >"$WORK/out.txt" 2>&1
warn_status=$?
if [ "$warn_status" = "0" ] && grep -q 'struck-through row' "$WORK/out.txt"; then
  ok "--warn-only reports the struck row and still exits 0"
else
  bad "--warn-only exit $warn_status / message missing -- retro posture broken"
fi

# --- The cli cells: one per distinct CLI outcome, the program compared byte for byte with the in-process call -----
seed "$HEADER
| ~~\`dev-s296-story-1\`~~ | \`dev-escalated\` | DELIVERED + CONSUMED | 2026-07-22 | — |"
vab_cell cli-vab-fail 1 "a struck In-Flight row fails" --root "$WORK" --only pipeline-snapshot.md
seed "$HEADER
| \`dev-s296-story-2\` | \`dev\` | docs/reviews/x.md | 2026-07-22 | in-flight |"
vab_cell cli-vab-pass 0 "an in-flight row passes" --root "$WORK" --only pipeline-snapshot.md

echo ""
report_end inflight-row-shape
