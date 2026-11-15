#!/usr/bin/env bash
# snapshot-evidence-cell — assert Check 15 can refuse a Check 14 row that was
# written without running the budget check.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# Check 14 runs the budget check and writes its own result into the gate log.
# Check 15 exists to verify that Check 14's assertion took effect. For every other
# part of Check 14 that verification reads the snapshot; for the budget there was
# nothing to read but the same self-report, so the loop closed on itself.
#
# It failed exactly that way in the reference consumer. v0.118.0 found 12
# consecutive Check 14 rows whose evidence cell read `-`, and required the verdict
# line be pasted instead. At gate `story-20260722T014002Z` the cell then read:
#
#     Budget validator: `PASS  validate-artifact-budget.sh` (exit 0).
#
# -- not empty, and not a "budget OK" paraphrase of the kind Check 15 already
# rejected. It was the validator's real PASS format, which at the time carried no
# run-specific content. The snapshot it named measured 126% of budget at the commit
# before that gate and 212% at the commit after; the validator exits 1 at both.
#
# Assertion 3 uses that literal string.
#
set -uo pipefail
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do [ "$_v" = AI_DLC_PROJECT_ROOT ] || unset "$_v"; done
unset CLAUDE_PROJECT_DIR

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

# The validator's gate-log fallback runs its SIBLING scope classifier (check-owed-derivations.sh), which
# runs ITS sibling sprint-status.sh (python3), which loads schemas/sprint-status.json from <script
# dir>/../schemas/; the shipped program reads them from its own tree.
VAL_DIR="$(dirname "$VALIDATOR")"
SIB_SCRIPTS="check-owed-derivations.sh sprint-status.sh"
if [ -f "$ROOT/core/schemas/sprint-status.json" ]; then
  SIB_SCHEMA="$ROOT/core/schemas/sprint-status.json"
elif [ -f "$ROOT/.claude/schemas/sprint-status.json" ]; then
  SIB_SCHEMA="$ROOT/.claude/schemas/sprint-status.json"
else
  echo "FIXTURE ERROR: schemas/sprint-status.json not found in either layout" >&2
  exit 2
fi
for sib in $SIB_SCRIPTS; do
  [ -f "$VAL_DIR/$sib" ] || { echo "FIXTURE ERROR: $VAL_DIR/$sib not found" >&2; exit 2; }
  echo "HERMETIC-CONSUMED $VAL_DIR/$sib"
done
echo "HERMETIC-CONSUMED $SIB_SCHEMA"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
# The consumer keeps its gate log one directory down, under
# _bmad-output/implementation-artifacts/. Seed it there rather than at the top, so
# the arm's own discovery is exercised and not bypassed.
mkdir -p "$WORK/_bmad-output/implementation-artifacts" || exit 2
GATELOG="$WORK/_bmad-output/implementation-artifacts/gate-log.md"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# Seed a gate log whose NEWEST gate section's Check 14 row is the argument. The
# older section's rows are deliberately older-format `-` cells: they were written
# under earlier rules, and indicting them retroactively would make this arm
# unpassable on any real consumer. The arm picks the section by its heading-block
# `Timestamp:` (step 12), so both sections carry one, and the snapshot's
# `last_gate_passed` names the newest -- without both, assertion 1 would fail on
# the SELECTION refusal and assertion 3 would pass for a reason it does not name.
SNAPSHOT="$WORK/_bmad-output/pipeline-snapshot.md"
seed() { # seed <newest-check-14-row>
  { printf '## Gate [planning] 2026-07-01\n\n'
    printf -- '- Timestamp: 2026-07-01T10:00:00Z. Result: PASSED.\n\n'
    printf '| Check | Verdict | Evidence |\n|---|---|---|\n'
    printf '| [core] 14 — Update pipeline snapshot | done after this entry | — |\n'
    printf '| [core] 15 — Verify snapshot reflects gate | done after Check 14 | — |\n\n'
    printf '## Gate [story] 2026-07-22\n\n'
    printf -- '- Timestamp: 2026-07-22T01:40:02Z. Result: PASSED.\n\n'
    printf '| Check | Verdict | Evidence |\n|---|---|---|\n'
    printf '%s\n' "$1"
  } > "$GATELOG"
  { printf '# Pipeline Snapshot\n\n## Pipeline Position\n\n'
    printf -- '- last_gate_passed: story at 2026-07-22T01:40:02Z\n'
    printf -- '- branch: ai-dlc/story/s296\n'
  } > "$SNAPSHOT"
}
# The heading line of the section every assertion below means to audit.
seed_story_line() { grep -n '^## Gate \[story\]' "$GATELOG" | cut -d: -f1; }

run_arm() {
  bash "$VALIDATOR" --root "$WORK" --check-evidence >"$WORK/out.txt" 2>&1
  echo "$?"
}

expect() { # expect <want-status> <label>
  local got; got="$(run_arm)"
  [ "$got" = "$1" ] && ok "$2" || { bad "$2 -- expected exit $1, got $got"; sed 's/^/        /' "$WORK/out.txt"; }
}

echo "snapshot-evidence-cell"

# --- 1. A pasted verdict line with its measurement passes ----------------------
seed '| [core] 14 — Update pipeline snapshot | PASS (lead) | `PASS  validate-artifact-budget.sh` / `  ok  _bmad-output/pipeline-snapshot.md   5432 tok  (budget   6000)` |'
expect 0 "a cell carrying the measurement passes"
# ...and it passes because the NEWEST section was audited, not by accident.
if grep -q "^selected section    : line $(seed_story_line) " "$WORK/out.txt" \
   && grep -q 'cites 5432 tok' "$WORK/out.txt"; then
  ok "  and the audited row is the story section's, citing 5432 tok"
else
  bad "  the pass did not come from the story section's row"
  sed 's/^/        /' "$WORK/out.txt"
fi

# --- 2. An empty cell fails ----------------------------------------------------
# The population v0.118.0 measured: 12 consecutive rows reading `-`. An empty cell
# is not a record that the check passed; it is a record that nothing was measured,
# and the two are indistinguishable afterwards.
seed '| [core] 14 — Update pipeline snapshot | done after this entry | — |'
expect 1 "an empty evidence cell fails"

# --- 3. THE CONTENT-FREE PASS STRING FAILS -------------------------------------
# The literal cell from `story-20260722T014002Z`. This is the assertion the whole
# change exists for: the string is the validator's real PASS format, it satisfies
# "paste the verdict line" and "not a restatement", and it was false.
seed '| [core] 14 — Update pipeline snapshot | PASS (lead) | `pipeline-snapshot.md` refreshed: Pipeline Position, Sprint Context unchanged. Budget validator: `PASS  validate-artifact-budget.sh` (exit 0). |'
expect 1 "the content-free PASS string fails (the S296 cell verbatim)"
if grep -q 'cites no budget measurement' "$WORK/out.txt"; then
  ok "  and the message says WHY -- no measurement, not 'over budget'"
else
  bad "  the message does not name the missing measurement"
fi

# --- 4. The short row shape is not passed vacuously ----------------------------
# Some gates append a compact per-check table (`| 14 | lead | ... |`) instead of
# the long form. Matching only the long form would let the short one through
# unmeasured -- a check that cannot fire reads exactly like one that passed.
seed '| 14 | lead | snapshot updated same gate |'
expect 1 "the compact row shape is matched, not skipped"

# --- 5. A breaching measurement cannot be laundered as PASS --------------------
# The second predicate. A row may not cite a number past the ceiling and call
# itself passing. Needs no tolerance and no file on disk -- it is a contradiction
# inside the row.
seed '| [core] 14 — Update pipeline snapshot | PASS (lead) | `OVER  _bmad-output/pipeline-snapshot.md   26,774 tok  (budget 6000)` |'
expect 1 "a PASS row citing 26,774 tok is refused"

# --- 7. A missing gate log is an explicit failure, never a silent pass ---------
# The arm finds its own gate log. If discovery returns nothing it must say so:
# "no gate log" resolving to exit 0 is the check-that-cannot-fire, one layer down.
rm -f "$GATELOG"
missing_status="$(run_arm)"
if [ "$missing_status" = "1" ] && grep -q 'no gate-log.md found' "$WORK/out.txt"; then
  ok "a missing gate log fails loudly rather than passing silently"
else
  bad "a missing gate log exited $missing_status -- discovery failure must not read as a pass"
fi

# =============================================================================
# DISCOVERY -- WHICH gate-log.md the arm reads.
#
# Assertions 1-7 all drive a root holding exactly ONE gate log, at the canonical
# path. Under that seed discovery cannot be wrong: whatever it returns is the
# file the arm was meant to read. So every arm above passes identically whether
# the arm prefers the live copy, sorts, reverses, or picks by directory hash --
# the seed is ADJACENT to the discriminating input and nothing below it is
# established.
#
# The real population has more than one. `find ... -name 'gate-log.md'` matches
# on BASENAME ALONE across the whole of `_bmad-output`, so any second copy
# anywhere under that tree qualifies, and readdir order decides which wins.
# Measured on a real consumer holding three: the winner was an ARCHIVED copy
# from a closed sprint, and this arm printed a normal PASS on its row while the
# live log's own row cited no measurement at all.
#
# TWO INDEPENDENT ORDERING PROPERTIES, AND A WORLD MUST ASSERT THE ONE IT USES.
# Readdir order on this filesystem is name-hash based -- not creation order and
# NOT lexical order. "Returned first by find" and "sorts lexically first" are
# separate facts about a directory name, and a world that needs one of them and
# assumes the other is a world whose verdict means nothing. Neither is a
# property this fixture may HARDCODE either: the hash is the host filesystem's,
# and this fixture ships to consumers running other ones. So every world below
# is BUILT, then MEASURED with find, and a name is accepted only once the order
# it needs has been observed in the world that will actually be driven.
#
# THE CANDIDATE POOLS ARE CHOSEN SO THE TWO PROPERTIES COINCIDE ON PURPOSE.
# Every early name sorts lexically before `implementation-artifacts` and every
# late name sorts after it, so an accepted early decoy is both lexically-first
# AND readdir-first -- which is what makes a `sort | head -1` non-fix reachable.
# =============================================================================

D="$WORK/discovery"
mkdir -p "$D" || exit 2

# The SUBJECT calls bare `find`; so does this fixture, resolved the same way, so
# a measurement here is a measurement of what the subject will see.
D_FIND="$(command -v find 2>/dev/null)"
if [ -z "$D_FIND" ]; then
  echo "FIXTURE ERROR: no find on PATH -- discovery order cannot be measured" >&2
  exit 2
fi

D_EARLY_POOL="a01-artifacts a02-artifacts a03-artifacts a04-artifacts a05-artifacts a06-artifacts a07-artifacts a08-artifacts a09-artifacts a10-artifacts a11-artifacts a12-artifacts"
D_LATE_POOL="z01-artifacts z02-artifacts z03-artifacts z04-artifacts z05-artifacts z06-artifacts z07-artifacts z08-artifacts z09-artifacts z10-artifacts z11-artifacts z12-artifacts"

# Top-level directory names under _bmad-output, in the order find returns their
# gate logs. This is the exact list `find | head -1` chooses from.
d_order_of() { # d_order_of <root>
  local r="$1" p rel out=""
  "$D_FIND" "$r/_bmad-output" -type f -name 'gate-log.md' 2>/dev/null > "$D/raw.txt"
  while IFS= read -r p; do
    rel="${p#"$r/_bmad-output/"}"
    out="$out ${rel%%/*}"
  done < "$D/raw.txt"
  printf '%s\n' "${out# }"
}

d_pos() { # d_pos <order-string> <name>  -> 1-based index, or 0 if absent
  local i=0 t
  for t in $1; do
    i=$((i+1))
    if [ "$t" = "$2" ]; then printf '%s\n' "$i"; return 0; fi
  done
  printf '0\n'
}

d_seed_log() { # d_seed_log <path> <evidence-cell>
  mkdir -p "${1%/*}" || return 1
  { printf '## Gate [story] 2026-07-22\n\n'
    printf '| Check | Verdict | Evidence |\n|---|---|---|\n'
    printf '| [core] 14 — Update pipeline snapshot | PASS (lead) | %s |\n' "$2"
  } > "$1"
}

# Drive a validator copy and report verdict/cited-number as one token.
d_verdict() { # d_verdict <script> <root> [extra args...]
  local s="$1" r="$2"; shift 2
  local st n
  bash "$s" --root "$r" --check-evidence "$@" >"$D/out.txt" 2>&1
  st=$?
  n="$(grep -oE 'cites [0-9]+ tok' "$D/out.txt" | tail -1)" || n=""
  n="${n#cites }"; n="${n% tok}"
  [ -n "$n" ] || n="-"
  if [ "$st" = "0" ]; then printf 'PASS/%s\n' "$n"; else printf 'FAIL%s/%s\n' "$st" "$n"; fi
}

# --- world builders -----------------------------------------------------------
# Each world gets its OWN fresh root, so a world defines its whole state and no
# earlier world's leftovers can be read as this one's seed.

# A BUILDER RUNS IN A COMMAND SUBSTITUTION, SO IT CANNOT SET A VARIABLE. Every
# assignment made inside `$( )` is lost to the subshell, and the caller then
# reads an EMPTY decoy name -- which `d_pos` scores as position 0, an ordering
# assertion nobody established. Each builder therefore PRINTS its findings on one
# line, `<root> <decoy> <late-or-dash> <order...>`, and the caller parses it.

d_field()  { printf '%s\n' "$1" | cut -d' ' -f"$2"; }
d_from()   { printf '%s\n' "$1" | cut -d' ' -f"$2"-; }

# canonical live copy + ONE decoy, REQUIRING the decoy readdir-BEFORE canonical.
d_world_two() { # d_world_two <canon-cell> <decoy-cell> <decoy-suffix>
  local canon_cell="$1" decoy_cell="$2" suffix="$3" name r order pc pd
  for name in $D_EARLY_POOL; do
    r="$(mktemp -d "$WORK/w2XXXXXX")" || return 1
    d_seed_log "$r/_bmad-output/implementation-artifacts/gate-log.md" "$canon_cell" || return 1
    d_seed_log "$r/_bmad-output/$name/$suffix/gate-log.md" "$decoy_cell" || return 1
    order="$(d_order_of "$r")"
    pc="$(d_pos "$order" implementation-artifacts)"
    pd="$(d_pos "$order" "$name")"
    if [ "$pd" -gt 0 ] && [ "$pc" -gt 0 ] && [ "$pd" -lt "$pc" ]; then
      printf '%s %s - %s\n' "$r" "$name" "$order"; return 0
    fi
  done
  return 1
}

# canonical live copy + one decoy BEFORE it and one decoy AFTER it. This is the
# only shape that separates a canonical preference from a `tail -1`: with the
# live copy readdir-last, `tail` picks it by accident and scores as a fix.
d_world_three() { # d_world_three <canon-cell> <early-cell> <late-cell> <suffix>
  local canon_cell="$1" early_cell="$2" late_cell="$3" suffix="$4"
  local e l r order pc pe pl
  for e in $D_EARLY_POOL; do
    for l in $D_LATE_POOL; do
      r="$(mktemp -d "$WORK/w3XXXXXX")" || return 1
      d_seed_log "$r/_bmad-output/implementation-artifacts/gate-log.md" "$canon_cell" || return 1
      d_seed_log "$r/_bmad-output/$e/$suffix/gate-log.md" "$early_cell" || return 1
      d_seed_log "$r/_bmad-output/$l/$suffix/gate-log.md" "$late_cell" || return 1
      order="$(d_order_of "$r")"
      pc="$(d_pos "$order" implementation-artifacts)"
      pe="$(d_pos "$order" "$e")"
      pl="$(d_pos "$order" "$l")"
      if [ "$pe" -gt 0 ] && [ "$pc" -gt 0 ] && [ "$pl" -gt 0 ] \
         && [ "$pe" -lt "$pc" ] && [ "$pc" -lt "$pl" ]; then
        printf '%s %s %s %s\n' "$r" "$e" "$l" "$order"; return 0
      fi
    done
  done
  return 1
}

CELL_5881='`  ok  _bmad-output/pipeline-snapshot.md   5881 tok  (budget   6000)`'
CELL_5120='`  ok  _bmad-output/pipeline-snapshot.md   5120 tok  (budget   6000)`'
CELL_4385='`  ok  _bmad-output/pipeline-snapshot.md   4385 tok  (budget   6000)`'
CELL_3070='`  ok  _bmad-output/pipeline-snapshot.md   3070 tok  (budget   6000)`'
CELL_NONE='done after this entry'

echo ""
echo "  -- discovery (find: $D_FIND) --"

# W1  zero gate logs.
W1="$(mktemp -d "$WORK/w1XXXXXX")" || exit 2
mkdir -p "$W1/_bmad-output/implementation-artifacts" || exit 2

# W2  A PAST SPRINT'S ARCHIVED COPY ONLY, no canonical copy. With no canonical
#     log the fallback reads the current sprint only (sprint 1 here, greenfield),
#     so s300/archive is neither current nor living and the loud failure is reached.
W2="$(mktemp -d "$WORK/w2oXXXXXX")" || exit 2
d_seed_log "$W2/_bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log.md" "$CELL_4385" || exit 2

# W2c the same shape under the CURRENT sprint (s1): the fallback still reads it.
W2C="$(mktemp -d "$WORK/w2cXXXXXX")" || exit 2
d_seed_log "$W2C/_bmad-output/planning-artifacts/s1/cycle-1/gate-log.md" "$CELL_4385" || exit 2

# W2h an archive/ copy under the CURRENT sprint: HISTORY beats CURRENT, so it is refused.
W2H="$(mktemp -d "$WORK/w2hXXXXXX")" || exit 2
d_seed_log "$W2H/_bmad-output/planning-artifacts/s1/archive/cycle-1/gate-log.md" "$CELL_4385" || exit 2

# W10 canonical cites 5881 + a CURRENT-sprint decoy (s1, not archive) readdir-first
#     and lexically first. The classifier calls both CURRENT or LIVING, so only the
#     canonical preference separates the live copy from a find-then-classify fallback.
R10="$(d_world_two "$CELL_5881" "$CELL_4385" 's1/cycle-1')" || {
  echo "FIXTURE BROKEN: no candidate name landed readdir-BEFORE implementation-artifacts (W10)" >&2; exit 2; }
W10="$(d_field "$R10" 1)"; W10_DECOY="$(d_field "$R10" 2)"; W10_ORDER="$(d_from "$R10" 4)"

# W3  live cites 5881 + archived decoy readdir-first.
R3="$(d_world_two "$CELL_5881" "$CELL_4385" 's300/archive/cycle-1')" || {
  echo "FIXTURE BROKEN: no candidate name landed readdir-BEFORE implementation-artifacts (W3)" >&2
  echo "  measured order in a two-log world: $(d_order_of "$W2")" >&2; exit 2; }
W3="$(d_field "$R3" 1)"; W3_DECOY="$(d_field "$R3" 2)"; W3_ORDER="$(d_from "$R3" 4)"

# W3b live cites a number that is NOT 5881. A fix that merely EMITS the string
#     the receipt looks for cannot produce 5120, because nothing here holds it.
R3B="$(d_world_two "$CELL_5120" "$CELL_4385" 's300/archive/cycle-1')" || {
  echo "FIXTURE BROKEN: no readdir-BEFORE candidate (W3b)" >&2; exit 2; }
W3B="$(d_field "$R3B" 1)"; W3B_DECOY="$(d_field "$R3B" 2)"; W3B_ORDER="$(d_from "$R3B" 4)"

# W5  live cites NOTHING while the archived copy cites. PASS before the fix,
#     FAIL after -- the deliberate tightening, and the reference consumer's shape.
R5="$(d_world_two "$CELL_NONE" "$CELL_4385" 's300/archive/cycle-1')" || {
  echo "FIXTURE BROKEN: no readdir-BEFORE candidate (W5)" >&2; exit 2; }
W5="$(d_field "$R5" 1)"; W5_DECOY="$(d_field "$R5" 2)"; W5_ORDER="$(d_from "$R5" 4)"

# W7  same shape as W3, driven with an explicit --gate-log. Discovery must be
#     short-circuited on BOTH sides of the change.
R7="$(d_world_two "$CELL_5881" "$CELL_4385" 's300/archive/cycle-1')" || {
  echo "FIXTURE BROKEN: no readdir-BEFORE candidate (W7)" >&2; exit 2; }
W7="$(d_field "$R7" 1)"; W7_DECOY="$(d_field "$R7" 2)"; W7_ORDER="$(d_from "$R7" 4)"

# W8  a decoy NOT under any `archive/` segment. The predicate is basename-only
#     across the whole tree; `archive/` is where the copies come from, not the
#     condition, and a fix keyed on that string leaves this world broken.
R8="$(d_world_two "$CELL_5881" "$CELL_4385" 's300/cycle-1')" || {
  echo "FIXTURE BROKEN: no readdir-BEFORE candidate (W8)" >&2; exit 2; }
W8="$(d_field "$R8" 1)"; W8_DECOY="$(d_field "$R8" 2)"; W8_ORDER="$(d_from "$R8" 4)"

# W9  decoys on BOTH sides of the live copy in readdir order.
R9="$(d_world_three "$CELL_5120" "$CELL_4385" "$CELL_3070" 's300/archive/cycle-1')" || {
  echo "FIXTURE BROKEN: no candidate pair straddled implementation-artifacts (W9)" >&2; exit 2; }
W9="$(d_field "$R9" 1)"; W9_EARLY="$(d_field "$R9" 2)"; W9_LATE="$(d_field "$R9" 3)"
W9_ORDER="$(d_from "$R9" 4)"

# --- 8. THE ORDERING PROPERTIES EACH WORLD DEPENDS ON, ASSERTED ---------------
# Read before any verdict below. A world whose decoy did not land readdir-first
# cannot exercise discovery at all, and its green reads exactly like a pass.
d_assert_before() { # d_assert_before <label> <order> <decoy>
  local pc pd
  pc="$(d_pos "$2" implementation-artifacts)"
  pd="$(d_pos "$2" "$3")"
  if [ "$pd" -gt 0 ] && [ "$pc" -gt 0 ] && [ "$pd" -lt "$pc" ]; then
    ok "$1 decoy '$3' is readdir-BEFORE the canonical copy (order: $2)"
  else
    bad "$1 ordering not established -- decoy at $pd, canonical at $pc (order: $2)"
  fi
  # The lexical property is INDEPENDENT of the readdir one and is asserted
  # separately, because `sort | head -1` keys on it and `find | head -1` does not.
  if [ "$(printf '%s\n%s\n' "$3" implementation-artifacts | LC_ALL=C sort | head -1)" = "$3" ]; then
    ok "$1 decoy '$3' also sorts lexically FIRST (a sort-based fix is reachable)"
  else
    bad "$1 decoy '$3' does not sort first -- a sort-based non-fix cannot be scored here"
  fi
}

d_assert_before "W3 " "$W3_ORDER"  "$W3_DECOY"
d_assert_before "W3b" "$W3B_ORDER" "$W3B_DECOY"
d_assert_before "W5 " "$W5_ORDER"  "$W5_DECOY"
d_assert_before "W7 " "$W7_ORDER"  "$W7_DECOY"
d_assert_before "W8 " "$W8_ORDER"  "$W8_DECOY"
d_assert_before "W10" "$W10_ORDER" "$W10_DECOY"

w9_pc="$(d_pos "$W9_ORDER" implementation-artifacts)"
w9_pe="$(d_pos "$W9_ORDER" "$W9_EARLY")"
w9_pl="$(d_pos "$W9_ORDER" "$W9_LATE")"
if [ "$w9_pe" -gt 0 ] && [ "$w9_pe" -lt "$w9_pc" ] && [ "$w9_pc" -lt "$w9_pl" ]; then
  ok "W9  decoys straddle the canonical copy in readdir order (order: $W9_ORDER)"
else
  bad "W9  straddle not established -- early $w9_pe, canonical $w9_pc, late $w9_pl (order: $W9_ORDER)"
fi

case "$W8_DECOY/s300/cycle-1" in
  *archive*) bad "W8  decoy path carries an 'archive' segment -- it cannot separate the two fixes" ;;
  *) ok "W8  decoy path carries NO 'archive' segment" ;;
esac

# --- 9. THE SHIPPED PROGRAM'S VERDICT IN EVERY WORLD ---------------------------
d_expect() { # d_expect <label> <want> <got>
  if [ "$2" = "$3" ]; then ok "$1 -> $3"; else bad "$1 -> got $3, expected $2"; fi
}

V_W1="$(d_verdict "$VALIDATOR" "$W1")"
V_W2="$(d_verdict "$VALIDATOR" "$W2")"
V_W3="$(d_verdict "$VALIDATOR" "$W3")"
V_W3B="$(d_verdict "$VALIDATOR" "$W3B")"
V_W5="$(d_verdict "$VALIDATOR" "$W5")"
V_W7="$(d_verdict "$VALIDATOR" "$W7" --gate-log "$W7/_bmad-output/implementation-artifacts/gate-log.md")"
V_W8="$(d_verdict "$VALIDATOR" "$W8")"
V_W9="$(d_verdict "$VALIDATOR" "$W9")"
V_W2C="$(d_verdict "$VALIDATOR" "$W2C")"
V_W2H="$(d_verdict "$VALIDATOR" "$W2H")"
V_W10="$(d_verdict "$VALIDATOR" "$W10")"

d_expect "W1  zero gate logs fail loudly           " "FAIL1/-"    "$V_W1"
d_expect "W2  a past sprint's archived log is no longer this gate's" "FAIL1/-"  "$V_W2"
d_expect "W2c the same shape under the current sprint PASSES" "PASS/4385"  "$V_W2C"
d_expect "W2h an archive/ log under the current sprint FAILS" "FAIL1/-"    "$V_W2H"
d_expect "W3  the live copy is read, not the decoy " "PASS/5881"  "$V_W3"
d_expect "W3b a live number that is not 5881       " "PASS/5120"  "$V_W3B"
d_expect "W5  a live row citing nothing now FAILS  " "FAIL1/-"    "$V_W5"
d_expect "W7  --gate-log short-circuits discovery  " "PASS/5881"  "$V_W7"
d_expect "W8  a decoy outside archive/ loses too   " "PASS/5881"  "$V_W8"
d_expect "W9  decoys on both sides, live still won " "PASS/5120"  "$V_W9"
d_expect "W10 a current-sprint decoy loses to live " "PASS/5881"  "$V_W10"

if grep -q 'no gate-log.md found' "$D/out.txt" 2>/dev/null; then :; fi
bash "$VALIDATOR" --root "$W1" --check-evidence >"$D/w1.txt" 2>&1
if grep -q 'no gate-log.md found' "$D/w1.txt"; then
  ok "W1  and the failure NAMES the missing gate log"
else
  bad "W1  failed without naming the missing gate log"
fi

# =============================================================================
# SELECTION -- WHICH Check 14 row the arm audits, once the log is chosen.
#
# The arm used to take the LAST Check 14 row in the file, on the premise that
# gate logs append. Measured on the reference consumer: its committed history
# appends, one sprint's live log PREPENDS (newest section first, so the last row
# was the oldest gate's 3052 tok instead of the audited 5076), and backfill logs
# put the newest section in the MIDDLE. Every positional rule is right on one of
# those and wrong on another, so the arm now picks the section whose heading
# block carries the greatest ISO `Timestamp:`, refuses a tie or a row-bearing
# section with none, and cross-checks the snapshot's `last_gate_passed` against
# the selected section's heading timestamps on the canonical live log only.
#
# Every world below has TWO OR MORE row-bearing sections. With one, the arm takes
# its fast path and never reaches the selector or the cross-check, so a world
# with one section would never exercise the selector at all.
#
# The verdict token is EXIT/CITED/CLASS. Several refusals share exit 1, and a
# program that trades one refusal for another differs only by the class.
#
# Seeds follow the producer's shape (`## Gate Log: Sprint N -- ... -- gate [g]
# at <step>`, a `- Timestamp:` bullet, a compact `gate_nonce`). The nonce
# `planning-20260929T051800Z` sits in EVERY heading block and is LATER than
# every ISO timestamp here: a stamp grammar that ever parsed the compact form
# would make it every section's maximum and turn every multi-section world into
# a tie, loudly.
# =============================================================================

E="$WORK/selection"
mkdir -p "$E" || exit 2
E_LIVE="_bmad-output/implementation-artifacts/gate-log.md"
T1="2026-08-10T09:00:00Z"; T2="2026-08-11T09:00:00Z"; T3="2026-08-12T09:00:00Z"

e_cell() { # e_cell <tok>  -> the evidence cell the real Check 14 pastes
  printf '`PASS  validate-artifact-budget.sh` `4:  ok  _bmad-output/pipeline-snapshot.md    %s tok  (budget   6000)`' "$1"
}

e_sec() { # e_sec <step> <timestamp|-> <row14-cell|-> [body-line]
  local step="$1" ts="$2" cell="$3" body="${4:-}"
  printf '## Gate Log: Sprint 400 — phase-400-fixture — gate [planning] at %s\n\n' "$step"
  printf -- '- Gate: planning (%s), variant carry-over, `gate_nonce` planning-20260929T051800Z, HEAD 111cf45ae17c.\n' "$step"
  [ "$ts" = "-" ] || printf -- '- Timestamp: %s. Result: PASSED.\n' "$ts"
  printf '\n| Check | Result | Evidence |\n|---|---|---|\n'
  printf '| [core] 13 — Artifacts committed | PASSED | HEAD 111cf45ae17c |\n'
  [ "$cell" = "-" ] || printf '| [core] 14 — Snapshot updated | PASSED | %s |\n' "$cell"
  printf '| [core] 15 — Snapshot verified | PASSED | see Check 14 |\n'
  [ -z "$body" ] || printf '\n%s\n' "$body"
  printf '\n'
}

e_root() { # e_root -> a fresh root holding only the live artifacts directory
  local r
  r="$(mktemp -d "$E/wXXXXXX")" || return 1
  mkdir -p "$r/_bmad-output/implementation-artifacts" || return 1
  printf '%s\n' "$r"
}

e_snap() { # e_snap <root> <last_gate_passed bullet, continuation lines included>
  { printf '# Pipeline Snapshot\n\n## Pipeline Position\n\n'
    printf '%s\n' "$2"
    printf -- '- branch: ai-dlc/carry-over/phase-400-fixture\n'
  } > "$1/_bmad-output/pipeline-snapshot.md"
}

# Line number of the heading of the section at <step> in <log>.
e_line() { grep -n "gate \[planning\] at $2\$" "$1" | cut -d: -f1; }

# Every builder writes the WHOLE world; nothing is shared between worlds.
e_new() { # e_new <var-for-root>  -- sets the named variable; refuses an empty root
  local r
  r="$(e_root)" || r=""
  [ -n "$r" ] && [ -d "$r" ] || { echo "FIXTURE ERROR: could not create a selection world" >&2; exit 2; }
  printf -v "$1" '%s' "$r"
}

# W-A  APPENDED, newest section last. The committed-history shape.
e_new WA
{ printf '# Gate Log\n\n'
  e_sec requirements "$T1" "$(e_cell 3100)"
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)"
} > "$WA/$E_LIVE"
e_snap "$WA" "- last_gate_passed: planning (stories) $T3"

# W-B  PREPENDED, newest section first. The s315 live-log shape.
e_new WB
{ printf '# Gate Log\n\n'
  e_sec stories      "$T3" "$(e_cell 5076)"
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec requirements "$T1" "$(e_cell 3052)"
} > "$WB/$E_LIVE"
e_snap "$WB" "- last_gate_passed: planning (stories) $T3"

# W-C  BACKFILL, newest section in the MIDDLE: its row is neither the first nor
#      the last Check 14 row in the file, so no positional rule reaches it.
e_new WC
{ printf '# Gate Log\n\n'
  e_sec requirements "$T1" "$(e_cell 4306)"
  e_sec stories      "$T3" "$(e_cell 5492)"
  e_sec architecture "$T2" "$(e_cell 3900)"
} > "$WC/$E_LIVE"
e_snap "$WC" "- last_gate_passed: planning (stories) $T3"

# W-D  STALE snapshot: the key names the PREVIOUS section, and the current row
#      cites nothing. Refused as stale; without the cross-check it is refused
#      only as uncited, which is the class this world separates.
e_new WD
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "evidence line below"
} > "$WD/$E_LIVE"
e_snap "$WD" "- last_gate_passed: planning (architecture) $T2"

# W-D2 STALE snapshot, current row DOES cite. Without the cross-check this
#      passes, so the kill is on the exit code and not only on the class.
e_new WD2
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)"
} > "$WD2/$E_LIVE"
e_snap "$WD2" "- last_gate_passed: planning (architecture) $T2"

# W-E  THE KEY QUOTED IN A LATER SECTION'S BODY (the 11bd10083 shape). The
#      stale key $T2 is the architecture heading's; the newer stories section
#      quotes it below its table. Heading-block search selects stories and
#      refuses the stale key; a body search finds $T2 in stories and passes.
e_new WE
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)" "- Carried the architecture gate's verdict of $T2 forward."
} > "$WE/$E_LIVE"
e_snap "$WE" "- last_gate_passed: planning (architecture) $T2"

# W-E2 A BODY TIMESTAMP LATER THAN EVERY HEADING, in the OLDER section (a
#      backfill annotation). A body search makes the older section newest.
e_new WE2
{ printf '# Gate Log\n\n'
  e_sec requirements "$T1" "$(e_cell 3100)" "- Re-checked at 2026-08-13T07:00:00Z after the architecture gate."
  e_sec architecture "$T2" "$(e_cell 5076)"
} > "$WE2/$E_LIVE"
e_snap "$WE2" "- last_gate_passed: planning (architecture) $T2"

# W-F  The key sits ONLY on a continuation line, ahead of a `(prior)` stamp, and
#      it is STALE. Reading the bullet line alone finds no key, skips the
#      cross-check and passes.
e_new WF
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)"
} > "$WF/$E_LIVE"
e_snap "$WF" "- last_gate_passed: planning (architecture)
  at $T2 (prior) planning (requirements) $T1"

# W-F2 The same continuation shape with the FRESH key: passes.
e_new WF2
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)"
} > "$WF2/$E_LIVE"
e_snap "$WF2" "- last_gate_passed: planning (stories)
  at $T3 (prior) planning (architecture) $T2"

# W-F3 The only stamp follows `(prior)`: it names the previous gate and is not a
#      key at all. Cut there, the key is absent and the newest-timestamp rule
#      stands; uncut, it would read as stale.
e_new WF3
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)"
} > "$WF3/$E_LIVE"
e_snap "$WF3" "- last_gate_passed: planning (stories) (prior) planning (architecture) $T2"

# W-G  MINUTE-precision headings against a SECONDS key.
e_new WG
{ printf '# Gate Log\n\n'
  e_sec architecture "2026-08-11T09:00Z" "$(e_cell 4200)"
  e_sec stories      "2026-08-12T09:00Z" "$(e_cell 5076)"
} > "$WG/$E_LIVE"
e_snap "$WG" "- last_gate_passed: planning (stories) 2026-08-12T09:00:00Z"

# W-H  NO snapshot key (the older `sprint-review,` form), prepended log: the
#      newest-timestamp rule alone selects.
e_new WH
{ printf '# Gate Log\n\n'
  e_sec stories      "$T3" "$(e_cell 5076)"
  e_sec architecture "$T2" "$(e_cell 4200)"
} > "$WH/$E_LIVE"
e_snap "$WH" "- last_gate_passed: sprint-review,"

# W-I  Two row-bearing sections TIE on the newest heading timestamp.
e_new WI
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T2" "$(e_cell 5076)"
} > "$WI/$E_LIVE"
e_snap "$WI" "- last_gate_passed: planning (stories) $T2"

# W-J  A row-bearing section with NO heading timestamp -- only the compact
#      nonce, which is not an ISO stamp. It is last in the file, so skipping it
#      selects the other section and passes on the wrong row.
e_new WJ
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      -     "$(e_cell 5076)"
} > "$WJ/$E_LIVE"
e_snap "$WJ" "- last_gate_passed: planning (architecture) $T2"

# W-K  ARCHIVED-ONLY log (a past sprint's) beside a live snapshot. The fallback
#      reads the current sprint only, so there is no log to audit and the arm
#      refuses loudly instead of passing on the archived copy.
e_new WK
mkdir -p "$WK/_bmad-output/planning-artifacts/s300/archive/cycle-1" || exit 2
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)"
} > "$WK/_bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log.md"
rm -f "$WK/$E_LIVE"
e_snap "$WK" "- last_gate_passed: implementation (gate-3) 2026-08-20T09:00:00Z"

# W-K2 The same log and snapshot under the CURRENT sprint (s1, not archive). The
#      fallback selects it, it is not the canonical live log, and the snapshot names
#      a different gate, so there is nothing to cross-check and the tree passes.
#      W-K is refused before the canonical test; this is the world that reaches it.
e_new WK2
mkdir -p "$WK2/_bmad-output/planning-artifacts/s1/cycle-1" || exit 2
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)"
} > "$WK2/_bmad-output/planning-artifacts/s1/cycle-1/gate-log.md"
rm -f "$WK2/$E_LIVE"
e_snap "$WK2" "- last_gate_passed: implementation (gate-3) 2026-08-20T09:00:00Z"

# W-L  The snapshot names a LATER gate whose section logged NO Check 14 row
#      (the reference consumer's implementation gate-3 shape). The refusal must
#      name that section, not call the snapshot stale.
e_new WL
{ printf '# Gate Log\n\n'
  e_sec architecture "$T1" "$(e_cell 4200)"
  e_sec stories      "$T2" "$(e_cell 5076)"
  e_sec gate-3       "$T3" -
} > "$WL/$E_LIVE"
e_snap "$WL" "- last_gate_passed: implementation (gate-3) $T3"

# W-M  A DATE-ONLY key hitting TWO row-less sections. The message names the
#      NEWEST of them, which is deliberately NOT the last one in the file.
e_new WM
{ printf '# Gate Log\n\n'
  e_sec architecture "2026-08-10T09:00:00Z" "$(e_cell 4200)"
  e_sec stories      "2026-08-14T09:00:00Z" "$(e_cell 5076)"
  e_sec gate-3b      "2026-08-13T15:00:00Z" -
  e_sec gate-3a      "2026-08-13T08:00:00Z" -
} > "$WM/$E_LIVE"
e_snap "$WM" "- last_gate_passed: implementation (gate-3) 2026-08-13"

# W-N  A DATE-ONLY key whose date is NOT the selected section's: refused.
e_new WN
{ printf '# Gate Log\n\n'
  e_sec architecture "2026-08-13T09:00:00Z" "$(e_cell 4200)"
  e_sec stories      "2026-08-14T09:00:00Z" "$(e_cell 5076)"
} > "$WN/$E_LIVE"
e_snap "$WN" "- last_gate_passed: planning (architecture) 2026-08-13"

# W-O  The same log with a DATE-ONLY key that IS the selected section's date.
e_new WO
{ printf '# Gate Log\n\n'
  e_sec architecture "2026-08-13T09:00:00Z" "$(e_cell 4200)"
  e_sec stories      "2026-08-14T09:00:00Z" "$(e_cell 5076)"
} > "$WO/$E_LIVE"
e_snap "$WO" "- last_gate_passed: planning (stories) 2026-08-14"

E_NAMES="W-A W-B W-C W-D W-D2 W-E W-E2 W-F W-F2 W-F3 W-G W-H W-I W-J W-K W-K2 W-L W-M W-N W-O"
E_ROOTS="$WA $WB $WC $WD $WD2 $WE $WE2 $WF $WF2 $WF3 $WG $WH $WI $WJ $WK $WK2 $WL $WM $WN $WO"
E_WANT="PASS/5076/- PASS/5076/- PASS/5492/- FAIL1/-/STALE FAIL1/-/STALE FAIL1/-/STALE PASS/5076/- FAIL1/-/STALE PASS/5076/- PASS/5076/- PASS/5076/- PASS/5076/- FAIL1/-/TIE FAIL1/-/NOTS FAIL1/-/- PASS/5076/- FAIL1/-/NOROW@$(e_line "$WL/$E_LIVE" gate-3) FAIL1/-/NOROW@$(e_line "$WM/$E_LIVE" gate-3b) FAIL1/-/STALE PASS/5076/-"

# EXIT/CITED/CLASS. The class is read from the refusal text, most specific first.
e_verdict() { # e_verdict <script> <root>
  local s="$1" r="$2" st n c
  bash "$s" --root "$r" --check-evidence >"$E/out.txt" 2>&1
  st=$?
  n="$(grep -oE 'cites [0-9]+ tok' "$E/out.txt" | tail -1)" || n=""
  n="${n#cites }"; n="${n% tok}"
  [ -n "$n" ] || n="-"
  # NOROW carries the line of the section it names, so naming the wrong
  # row-less section is a different token.
  if   grep -q 'logged no Check 14 row' "$E/out.txt"; then
    c="$(grep -oE 'section heads line [0-9]+' "$E/out.txt" | head -1)" || c=""
    c="NOROW@${c##* }"
  elif grep -q 'The snapshot is stale or names a different gate' "$E/out.txt"; then c=STALE
  elif grep -q 'carries no ISO timestamp in its heading block' "$E/out.txt";   then c=NOTS
  elif grep -q 'tie on the newest heading timestamp' "$E/out.txt";      then c=TIE
  elif grep -q 'cites no budget measurement' "$E/out.txt";              then c=NOCITE
  elif grep -q 'past the [0-9]* ceiling' "$E/out.txt";                  then c=OVER
  else c="-"; fi
  if [ "$st" = "0" ]; then printf 'PASS/%s/%s\n' "$n" "$c"; else printf 'FAIL%s/%s/%s\n' "$st" "$n" "$c"; fi
}

e_vector() { # e_vector <script>
  local r out=""
  for r in $E_ROOTS; do out="$out $(e_verdict "$1" "$r")"; done
  printf '%s\n' "${out# }"
}

echo ""
echo "  -- selection --"

# --- 13. THE SHAPES THE WORLDS DEPEND ON, ASSERTED BEFORE ANY VERDICT ----------
e_rowlines() { grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*(\||—|-)' "$1" | cut -d: -f1; }
wc_rows="$(e_rowlines "$WC/$E_LIVE" | tr '\n' ' ')"
wc_first="$(printf '%s\n' $wc_rows | head -1)"
wc_last="$(printf '%s\n' $wc_rows | tail -1)"
wc_right="$(grep -n ' 5492 tok ' "$WC/$E_LIVE" | cut -d: -f1)"
if [ -n "$wc_right" ] && [ -n "$wc_first" ] && [ "$wc_first" -lt "$wc_right" ] && [ "$wc_right" -lt "$wc_last" ]; then
  ok "W-C the newest section's row (line $wc_right) is neither the first ($wc_first) nor the last ($wc_last) Check 14 row"
else
  bad "W-C row placement not established -- rows [$wc_rows], newest row at '$wc_right'"
fi
e_nsecs=0
for r in $E_ROOTS; do
  l="$r/$E_LIVE"; [ -f "$l" ] || l="$(find "$r/_bmad-output" -type f -name gate-log.md | head -1)"
  n="$(LC_ALL=C awk '/^## /{s=NR} /^\| \[core\] 14 /{h[s]=1} END{c=0; for(k in h)c++; print c}' "$l")"
  [ "$n" -ge 2 ] && e_nsecs=$((e_nsecs+1))
done
if [ "$e_nsecs" -eq 20 ]; then
  ok "all 20 selection worlds carry two or more row-bearing sections (none takes the fast path)"
else
  bad "only $e_nsecs of 20 selection worlds carry two or more row-bearing sections"
fi

# --- 14. THE SHIPPED PROGRAM'S VERDICT IN EVERY WORLD -------------------------
E_SHIPPED="$(e_vector "$VALIDATOR")"
i=0
for w in $E_NAMES; do
  i=$((i+1))
  got="$(printf '%s\n' "$E_SHIPPED" | cut -d' ' -f"$i")"
  want="$(printf '%s\n' "$E_WANT" | cut -d' ' -f"$i")"
  if [ "$got" = "$want" ]; then ok "$w -> $got"; else bad "$w -> got $got, expected $want"; fi
done

# The refusal and the selection NAME the right section, not merely some section.
# Captured first and fed by a here-string: `grep -q` fed from a pipe under
# pipefail answers with the writer's EPIPE and reads a present string as absent.
e_has() { # e_has <label> <root> <fixed-string>
  local msg
  msg="$(bash "$VALIDATOR" --root "$2" --check-evidence 2>&1)"
  if grep -qF -- "$3" <<<"$msg"; then ok "$1"; else bad "$1 -- no '$3' in:"; printf '%s\n' "$msg" | sed 's/^/        /'; fi
}
e_has "W-A selects the stories section by its heading timestamp" "$WA" \
  "selected section    : line $(e_line "$WA/$E_LIVE" stories) (newest heading timestamp ${T3%Z}; snapshot key ${T3%Z})"
e_has "W-C selects the middle section" "$WC" \
  "selected section    : line $(e_line "$WC/$E_LIVE" stories) (newest heading timestamp ${T3%Z}"
e_has "W-E refusal names the heading-timestamp section, not the body that quotes the key" "$WE" \
  "(line $(e_line "$WE/$E_LIVE" stories), ${T3%Z})"
e_has "W-H reports the snapshot key as absent" "$WH" "snapshot key absent)"
e_has "W-K refuses: a past sprint's archived log is not the current sprint's" "$WK" \
  "for the current sprint"
e_has "W-L names the gate-3 section that logged no Check 14 row" "$WL" \
  "the gate whose section heads line $(e_line "$WL/$E_LIVE" gate-3):"
e_has "W-M names the NEWEST row-less section carrying the date, not the last" "$WM" \
  "the gate whose section heads line $(e_line "$WM/$E_LIVE" gate-3b):"

echo ""
report_end snapshot-evidence-cell
