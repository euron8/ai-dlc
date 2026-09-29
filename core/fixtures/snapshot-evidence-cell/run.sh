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
# Assertion 3 uses that literal string. Assertion 6 is the control.

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
# The consumer keeps its gate log one directory down, under
# _bmad-output/implementation-artifacts/. Seed it there rather than at the top, so
# the arm's own discovery is exercised and not bypassed.
mkdir -p "$WORK/_bmad-output/implementation-artifacts" || exit 2
GATELOG="$WORK/_bmad-output/implementation-artifacts/gate-log.md"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

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

# --- 6. THE MUTATION TEST — prove the reds come from the new arm ---------------
# Strip the arm's dispatch from a COPY. Without it the flag falls through to the
# ordinary measuring path, which has no artifacts to measure here and exits 0. If
# assertion 3's input still failed, something else was producing the red.
MUTANT="$WORK/mutant.sh"
sed 's/^if \[ "\$CHECK_EVIDENCE" -eq 1 \]; then$/if false; then/' "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the arm's dispatch was renamed" >&2
  echo "  update the sed pattern in assertion 6 to match the real guard" >&2
  exit 2
fi
seed '| [core] 14 — Update pipeline snapshot | PASS (lead) | Budget validator: `PASS  validate-artifact-budget.sh` (exit 0). |'
bash "$MUTANT" --root "$WORK" --check-evidence >"$WORK/mut-out.txt" 2>&1
mutant_status=$?
if [ "$mutant_status" = "0" ]; then
  ok "MUTATION: removing the arm makes assertion 3's input go green"
else
  bad "MUTATION: assertion 3's input still fails (exit $mutant_status) without the arm -- it proves nothing"
  sed 's/^/        /' "$WORK/mut-out.txt"
fi

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

# W2  ARCHIVED COPY ONLY, no canonical copy. This is the world an `archive/`
#     exclusion regresses: it passes today and must keep passing.
W2="$(mktemp -d "$WORK/w2oXXXXXX")" || exit 2
d_seed_log "$W2/_bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log.md" "$CELL_4385" || exit 2

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

d_expect "W1  zero gate logs fail loudly           " "FAIL1/-"    "$V_W1"
d_expect "W2  an archived-only tree still PASSES   " "PASS/4385"  "$V_W2"
d_expect "W3  the live copy is read, not the decoy " "PASS/5881"  "$V_W3"
d_expect "W3b a live number that is not 5881       " "PASS/5120"  "$V_W3B"
d_expect "W5  a live row citing nothing now FAILS  " "FAIL1/-"    "$V_W5"
d_expect "W7  --gate-log short-circuits discovery  " "PASS/5881"  "$V_W7"
d_expect "W8  a decoy outside archive/ loses too   " "PASS/5881"  "$V_W8"
d_expect "W9  decoys on both sides, live still won " "PASS/5120"  "$V_W9"

if grep -q 'no gate-log.md found' "$D/out.txt" 2>/dev/null; then :; fi
bash "$VALIDATOR" --root "$W1" --check-evidence >"$D/w1.txt" 2>&1
if grep -q 'no gate-log.md found' "$D/w1.txt"; then
  ok "W1  and the failure NAMES the missing gate log"
else
  bad "W1  failed without naming the missing gate log"
fi

# --- 10. MUTANTS ---------------------------------------------------------------
# Every mutant is a COPY, asserted APPLIED by `cmp -s`, asserted PARSEABLE by
# `bash -n`, and asserted to have removed or added the SUBJECT'S OWN PREDICATE by
# a pre/post count -- never by a hand-listed site. "Mutant did not apply" reads
# exactly like "mutant was killed", and a mutant that dies on a syntax error
# reads like one that was killed too.
#
# The validator sources no siblings and resolves nothing beside itself (measured:
# zero `source`/`.` lines, zero SCRIPT_DIR references), so a lone script copy is
# a complete program. It takes its root from --root, so it never reads this repo.

d_pre_canon="$(grep -cE '^[^#]*implementation-artifacts/gate-log\.md' "$VALIDATOR")" || d_pre_canon=0
d_pre_find="$(grep -cE '^[^#]*GATE_LOG="\$\(find ' "$VALIDATOR")" || d_pre_find=0

mut_applied=0
d_mut() { # d_mut <name> <outfile> ; builds by transforming $VALIDATOR
  local name="$1" out="$2"
  case "$name" in
    ctl)
      cat "$VALIDATOR" > "$out" ;;
    base|sort|tail|uncond)
      # Revert the canonical preference: drop the `if -f`, its taken branch and
      # the `else`, leaving the original `find | head -1` alone in the block.
      LC_ALL=C awk '
        skip == 1 { if ($0 == "    else") { skip = 0 } ; next }
        $0 == "    if [ -f \"$ROOT/_bmad-output/implementation-artifacts/gate-log.md\" ]; then" { skip = 1; hit = 1; next }
        hit == 1 && shut == 0 && $0 == "    fi" { shut = 1; next }
        { print }
      ' "$VALIDATOR" > "$out" || return 1
      case "$name" in
        sort)   LC_ALL=C awk '
                  index($0, "GATE_LOG=\"$(find ") > 0 {
                    print "      GATE_LOG=\"$(find \"$ROOT/_bmad-output\" -type f -name '\''gate-log.md'\'' 2>/dev/null | LC_ALL=C sort | head -1)\""
                    next }
                  { print }' "$out" > "$out.t" && mv "$out.t" "$out" || return 1 ;;
        tail)   LC_ALL=C awk '
                  index($0, "GATE_LOG=\"$(find ") > 0 {
                    print "      GATE_LOG=\"$(find \"$ROOT/_bmad-output\" -type f -name '\''gate-log.md'\'' 2>/dev/null | tail -1)\""
                    next }
                  { print }' "$out" > "$out.t" && mv "$out.t" "$out" || return 1 ;;
        uncond) LC_ALL=C awk '
                  { print }
                  index($0, "| tr -d '\'', '\'' | sed") > 0 && done == 0 { print "  CITED=5881"; done = 1 }
                  ' "$out" > "$out.t" && mv "$out.t" "$out" || return 1 ;;
      esac ;;
    hard)
      # Discovery DELETED: the canonical path, always, with no fallback at all.
      LC_ALL=C awk '
        st == 0 && $0 == "    if [ -f \"$ROOT/_bmad-output/implementation-artifacts/gate-log.md\" ]; then" { st = 1; next }
        st == 1 && $0 == "      GATE_LOG=\"$ROOT/_bmad-output/implementation-artifacts/gate-log.md\"" { print "    GATE_LOG=\"$ROOT/_bmad-output/implementation-artifacts/gate-log.md\""; st = 2; next }
        st == 2 && $0 == "    else" { st = 3; next }
        st == 3 { st = 4; next }
        st == 4 && $0 == "    fi" { st = 5; next }
        { print }
      ' "$VALIDATOR" > "$out" || return 1 ;;
    noop)
      # A transformation that MATCHES NOTHING. The applied-assertion's own probe.
      LC_ALL=C awk '$0 == "ZZZ-THIS-LINE-CANNOT-EXIST-IN-THE-SUBJECT" { next } { print }' "$VALIDATOR" > "$out" || return 1 ;;
    broken)
      # A mutant that APPLIES and does not PARSE. The bash -n probe's subject.
      { cat "$VALIDATOR"; printf 'if [ 1 -eq 1 ; then\n'; } > "$out" || return 1 ;;
  esac
  return 0
}

# Build, and refuse anything that did not apply, did not parse, or did not move
# the subject's own predicate.
# <want-applied> is 1 for a real mutant, 0 for the no-op probe, and `same` for
# the unmutated control -- which is byte-identical BY CONSTRUCTION and must not
# be refused for it. Treating the control as a failed mutation is a false red on
# the one arm whose whole job is to say the harness did not move.
d_build() { # d_build <name> <want-applied:1|0|same> <post-canon> <post-find>
  local name="$1" want="$2" wc="$3" wf="$4" out="$D/$1.sh" pc pf
  d_mut "$name" "$out" || { bad "MUTANT $name: builder FAILED -- no mutant was scored"; return 1; }
  if cmp -s "$VALIDATOR" "$out"; then
    if [ "$want" = "0" ]; then
      ok "MUTANT $name: DID NOT APPLY, and that is what this probe asserts"
      return 1
    fi
    if [ "$want" != "same" ]; then
      bad "MUTANT $name: DID NOT APPLY -- 'matched nothing' reads exactly like 'was killed'"
      return 1
    fi
  elif [ "$want" = "same" ]; then
    bad "CONTROL $name: differs from the subject -- an unmutated control must be byte-identical"
    return 1
  elif [ "$want" = "0" ]; then
    bad "MUTANT $name: applied, but this probe requires a transformation that matches nothing"
    return 1
  fi
  if ! bash -n "$out" 2>"$D/$name.syn"; then
    if [ "$name" = "broken" ]; then
      ok "MUTANT broken: refused by bash -n, so an unparseable mutant cannot score a kill"
      return 1
    fi
    bad "MUTANT $name: does not parse -- a dead mutant is not a killed one"
    sed 's/^/        /' "$D/$name.syn"
    return 1
  fi
  if [ "$name" = "broken" ]; then
    bad "MUTANT broken: parsed, so the bash -n probe has no subject"
    return 1
  fi
  pc="$(grep -cE '^[^#]*implementation-artifacts/gate-log\.md' "$out")" || pc=0
  pf="$(grep -cE '^[^#]*GATE_LOG="\$\(find ' "$out")" || pf=0
  if [ "$pc" != "$wc" ] || [ "$pf" != "$wf" ]; then
    bad "MUTANT $name: predicate not as specified -- canonical lines $pc (want $wc), find lines $pf (want $wf)"
    return 1
  fi
  mut_applied=$((mut_applied+1))
  ok "MUTANT $name: applied, parses, predicate $d_pre_canon/$d_pre_find -> $pc/$pf"
  return 0
}

echo ""
echo "  -- mutants --"

d_build noop   0    0 0 || true
d_build broken 1    0 0 || true
d_build ctl    same "$d_pre_canon" "$d_pre_find" || true
d_build base   1 0 1 || true
d_build sort   1 0 1 || true
d_build tail   1 0 1 || true
d_build hard   1 1 0 || true
d_build uncond 1 0 1 || true

if [ "$mut_applied" -eq 6 ]; then
  ok "all six scoreable mutants applied (ctl, base, sort, tail, hard, uncond)"
else
  bad "only $mut_applied of 6 scoreable mutants applied -- the table below is incomplete"
fi

# --- 11. THE KILL TABLE --------------------------------------------------------
# A variant is KILLED when its verdict vector differs from the shipped program's
# on at least one world, and the world is NAMED. The unmutated control must have
# the IDENTICAL vector -- and must also carry a POSITIVE row, so a copy that
# never ran cannot score as agreement.

d_vector() { # d_vector <script>
  printf '%s %s %s %s %s %s %s %s\n' \
    "$(d_verdict "$1" "$W1")" \
    "$(d_verdict "$1" "$W2")" \
    "$(d_verdict "$1" "$W3")" \
    "$(d_verdict "$1" "$W3B")" \
    "$(d_verdict "$1" "$W5")" \
    "$(d_verdict "$1" "$W7" --gate-log "$W7/_bmad-output/implementation-artifacts/gate-log.md")" \
    "$(d_verdict "$1" "$W8")" \
    "$(d_verdict "$1" "$W9")"
}

D_WORLDS="W1 W2 W3 W3b W5 W7 W8 W9"
SHIPPED_VEC="$(d_vector "$VALIDATOR")"
printf '  %-8s %s\n' "SHIPPED" "$SHIPPED_VEC"

# EVERY world that differs, not the first. A mutant killed by one world only is a
# mutant whose world is LOAD-BEARING, and that is a fact worth asserting rather
# than reading off a table -- a later hardening world can silently become the
# reason a kill still scores, and then the motivating world can be deleted with
# nothing going red.
d_diff_worlds() { # d_diff_worlds <vec-a> <vec-b>  -> space-separated world names
  local i=0 w a b out=""
  for w in $D_WORLDS; do
    i=$((i+1))
    a="$(d_field "$1" "$i")"
    b="$(d_field "$2" "$i")"
    [ "$a" = "$b" ] || out="$out $w"
  done
  printf '%s\n' "${out# }"
}

d_score() { # d_score <name> <must-differ:1|0> [sole-killing-world]
  local name="$1" must="$2" sole="${3:-}" vec diff
  [ -f "$D/$name.sh" ] || { bad "KILL $name: no mutant on disk to score"; return; }
  vec="$(d_vector "$D/$name.sh")"
  printf '  %-8s %s\n' "$name" "$vec"
  diff="$(d_diff_worlds "$SHIPPED_VEC" "$vec")"
  if [ "$must" = "1" ]; then
    if [ -n "$diff" ]; then
      ok "KILL $name: differs from the shipped program at [$diff]"
    else
      bad "KILL $name: SURVIVED every world -- no seed here separates it from the fix"
    fi
    if [ -n "$sole" ]; then
      if [ "$diff" = "$sole" ]; then
        ok "  and $sole is the ONLY world that kills it -- deleting $sole would lose this kill"
      else
        bad "  $sole was recorded as $name's only killer; it now dies at [$diff]. Re-derive which world is load-bearing before trusting either."
      fi
    fi
  else
    if [ -n "$diff" ]; then
      bad "CONTROL $name: an UNMUTATED copy disagreed at $diff -- the harness is what moved"
    else
      case "$vec" in
        *PASS/5881*) ok "CONTROL $name: unmutated copy agrees, and DID run (a PASS/5881 row is present)" ;;
        *) bad "CONTROL $name: agrees but emitted no PASS/5881 row -- two inert runs compare equal" ;;
      esac
    fi
  fi
}

d_score ctl    0
d_score base   1
d_score sort   1
# W9 IS THE ONLY WORLD THAT KILLS `tail`, AND THAT IS ASSERTED, NOT OBSERVED. In
# every two-log world here the canonical copy is readdir-LAST, so `tail -1` picks
# the live log by accident and scores identically to the fix. Only a world with a
# decoy on each side separates them.
d_score tail   1 W9
d_score hard   1
d_score uncond 1

# --- 12. THE MUTATION ANCHOR OF ASSERTION 6 IS STILL UNIQUE --------------------
# Assertion 6 anchors a sed on the arm's dispatch line. That line is the one
# thing in this arm the discovery change must NOT have moved; if it ever does,
# assertion 6 goes vacuous while still printing ok.
anchor_n="$(grep -cE '^if \[ "\$CHECK_EVIDENCE" -eq 1 \]; then$' "$VALIDATOR")" || anchor_n=0
if [ "$anchor_n" = "1" ]; then
  ok "assertion 6's dispatch anchor still matches exactly once"
else
  bad "assertion 6's dispatch anchor matches $anchor_n times -- that mutation is no longer sound"
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
# with one section would score every selector mutant as a survivor for a reason
# that has nothing to do with the selector.
#
# The verdict token is EXIT/CITED/CLASS. Several refusals share exit 1, and a
# mutant that trades one refusal for another is killed only by the class.
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

# W-K  ARCHIVED-ONLY log beside a live snapshot whose key matches no section.
#      The snapshot describes a different gate than this log's, so there is
#      nothing to cross-check and the tree must keep passing.
e_new WK
mkdir -p "$WK/_bmad-output/planning-artifacts/s300/archive/cycle-1" || exit 2
{ printf '# Gate Log\n\n'
  e_sec architecture "$T2" "$(e_cell 4200)"
  e_sec stories      "$T3" "$(e_cell 5076)"
} > "$WK/_bmad-output/planning-artifacts/s300/archive/cycle-1/gate-log.md"
rm -f "$WK/$E_LIVE"
e_snap "$WK" "- last_gate_passed: implementation (gate-3) 2026-08-20T09:00:00Z"

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

E_NAMES="W-A W-B W-C W-D W-D2 W-E W-E2 W-F W-F2 W-F3 W-G W-H W-I W-J W-K W-L W-M W-N W-O"
E_ROOTS="$WA $WB $WC $WD $WD2 $WE $WE2 $WF $WF2 $WF3 $WG $WH $WI $WJ $WK $WL $WM $WN $WO"
E_WANT="PASS/5076/- PASS/5076/- PASS/5492/- FAIL1/-/STALE FAIL1/-/STALE FAIL1/-/STALE PASS/5076/- FAIL1/-/STALE PASS/5076/- PASS/5076/- PASS/5076/- PASS/5076/- FAIL1/-/TIE FAIL1/-/NOTS PASS/5076/- FAIL1/-/NOROW@$(e_line "$WL/$E_LIVE" gate-3) FAIL1/-/NOROW@$(e_line "$WM/$E_LIVE" gate-3b) FAIL1/-/STALE PASS/5076/-"

# EXIT/CITED/CLASS. The class is read from the refusal text, most specific first.
e_verdict() { # e_verdict <script> <root>
  local s="$1" r="$2" st n c
  bash "$s" --root "$r" --check-evidence >"$E/out.txt" 2>&1
  st=$?
  n="$(grep -oE 'cites [0-9]+ tok' "$E/out.txt" | tail -1)" || n=""
  n="${n#cites }"; n="${n% tok}"
  [ -n "$n" ] || n="-"
  # NOROW carries the line of the section it names, so a mutant naming the wrong
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
if [ "$e_nsecs" -eq 19 ]; then
  ok "all 19 selection worlds carry two or more row-bearing sections (none takes the fast path)"
else
  bad "only $e_nsecs of 19 selection worlds carry two or more row-bearing sections"
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
e_has "W-K reports the cross-check as not applied off the canonical log" "$WK" \
  "snapshot key not checked: not the canonical live gate log)"
e_has "W-L names the gate-3 section that logged no Check 14 row" "$WL" \
  "the gate whose section heads line $(e_line "$WL/$E_LIVE" gate-3):"
e_has "W-M names the NEWEST row-less section carrying the date, not the last" "$WM" \
  "the gate whose section heads line $(e_line "$WM/$E_LIVE" gate-3b):"

# --- 15. SELECTOR MUTANTS -------------------------------------------------------
# Each is a COPY of the validator with ONE predicate changed, built by an awk that
# counts its own anchor hits. A hit count other than the one specified, a copy
# byte-identical to the subject, or a copy that does not parse is reported as DID
# NOT APPLY and scores nothing. Anchors reach awk through ENVIRON, never `-v`,
# because several carry a literal `\t` that `-v` would turn into a tab.
e_applied=0
e_mut() { # e_mut <name> <line|sub> <anchor> <replacement> <want-hits>
  local name="$1" mode="$2" out="$E/$1.sh" hits
  hits="$(A="$3" R="$4" M="$mode" LC_ALL=C awk -v out="$out" '
    BEGIN { a = ENVIRON["A"]; r = ENVIRON["R"]; m = ENVIRON["M"]; h = 0 }
    {
      if (m == "line" && $0 == a) { print r > out; h++; next }
      if (m == "sub" && (i = index($0, a)) > 0) { print substr($0, 1, i - 1) r substr($0, i + length(a)) > out; h++; next }
      print > out
    }
    END { close(out); print h }' "$VALIDATOR")" || hits="awk-failed"
  if [ "$5" = "0" ]; then
    if [ "$hits" = "0" ] && cmp -s "$VALIDATOR" "$out"; then
      ok "MUTANT $name: DID NOT APPLY, and that is what this probe asserts"
    else
      bad "MUTANT $name: the no-op probe hit $hits line(s) -- the hit counter cannot be trusted"
    fi
    return 1
  fi
  if [ "$hits" != "$5" ]; then
    bad "MUTANT $name: DID NOT APPLY -- anchor hit $hits line(s), want $5"; return 1
  fi
  if cmp -s "$VALIDATOR" "$out"; then
    bad "MUTANT $name: DID NOT APPLY -- copy is byte-identical to the subject"; return 1
  fi
  if ! bash -n "$out" 2>"$E/$name.syn"; then
    bad "MUTANT $name: does not parse -- a dead mutant is not a killed one"
    sed 's/^/        /' "$E/$name.syn"; return 1
  fi
  e_applied=$((e_applied+1))
  ok "MUTANT $name: applied at $hits site(s), parses"
  return 0
}

e_mut enoop line 'ZZZ-THIS-LINE-CANNOT-EXIST-IN-THE-SUBJECT' 'x' 0 || true
cat "$VALIDATOR" > "$E/ectl.sh" || exit 2
# Positional selection, both directions: the fast path taken for ANY row count,
# auditing the first (head) or the last (tail) row-bearing section.
e_mut pfirst line \
  '      if (n == 1) { printf "ONE\t%s\t%s\n", order[1], last[order[1]]; exit }' \
  '      if (n >= 1) { printf "ONE\t%s\t%s\n", order[1], last[order[1]]; exit }' 1 || true
e_mut plast line \
  '      if (n == 1) { printf "ONE\t%s\t%s\n", order[1], last[order[1]]; exit }' \
  '      if (n >= 1) { printf "ONE\t%s\t%s\n", order[n], last[order[n]]; exit }' 1 || true
# The snapshot cross-check dropped: every key is accepted.
e_mut noxcheck line '      SNAP_OK=0' '      SNAP_OK=1' 1 || true
# Timestamps read from the whole section, body included.
e_mut body line \
  '    inb             { ts[sec] = ts[sec] stamps($0) }' \
  '    1               { ts[sec] = ts[sec] stamps($0) }' 1 || true
# The key read from the bullet line alone: stop at the first line after it.
e_mut oneline line \
  '      on && (/^[[:space:]]*$/ || /^[^[:space:]]/ || /^[[:space:]]*[-*][[:space:]]/) { exit }' \
  '      on { exit }' 1 || true
# No precision normalisation, at EVERY site that normalises (heading stamps,
# snapshot key, key search) -- reverting one leaves the others to cover it.
e_mut noprec sub 't = t ":00"' 't = t' 3 || true
# A tie accepted: the first of the tied sections wins.
e_mut tie line '        else if (m == best) tie = s' '        else if (m == best) tie = ""' 1 || true
# A row-bearing section with no heading timestamp skipped instead of refused.
e_mut skipnots line \
  '        if (m == "") { printf "NOTS\t%s\n", s; exit }' \
  '        if (m == "") continue' 1 || true
# The cross-check applied to ANY log, canonical or not.
e_mut xcanon line '    if [ "$GATE_LOG" != "$LIVE_DIR/gate-log.md" ]; then' '    if false; then' 1 || true
# The no-Check-14-row message collapsed into the stale one.
e_mut nohit line '        if [ -n "$HIT_SEC" ] && [ "$HIT_ROW" = "0" ]; then' '        if false; then' 1 || true
# A date-only key treated as absent.
e_mut dateabsent line '          print t' '          if (length(t) > 10) print t' 1 || true
# The `(prior)` cut dropped: the previous gate's stamp is read as the key.
e_mut noprior sub 'if (i) buf = substr(buf, 1, i - 1)' 'if (0) buf = substr(buf, 1, i - 1)' 1 || true
# The key's section taken as the LAST in the file carrying it, not the newest.
e_mut lasthit sub 'if (hit && t >= best) { best = t; bsec = sec }' 'if (hit) { best = t; bsec = sec }' 1 || true

if [ "$e_applied" -eq 13 ]; then
  ok "all thirteen selector mutants applied"
else
  bad "only $e_applied of 13 selector mutants applied -- the kill table below is incomplete"
fi

# --- 16. THE SELECTOR KILL TABLE -----------------------------------------------
# A mutant is KILLED by a world when its token there differs from the shipped
# program's. Each mutant must die in the world named for it; every killing world
# is printed, so a kill that has moved to a different world is visible.
printf '  %-10s %s\n' "worlds" "$E_NAMES"
printf '  %-10s %s\n' "SHIPPED" "$E_SHIPPED"
e_diff() { # e_diff <vec-a> <vec-b> -> names of the worlds where they differ
  local i=0 w out=""
  for w in $E_NAMES; do
    i=$((i+1))
    [ "$(printf '%s\n' "$1" | cut -d' ' -f"$i")" = "$(printf '%s\n' "$2" | cut -d' ' -f"$i")" ] || out="$out $w"
  done
  printf '%s\n' "${out# }"
}
e_score() { # e_score <name> <world-that-must-kill>...
  local name="$1" vec diff w; shift
  [ -f "$E/$name.sh" ] || { bad "KILL $name: no mutant on disk to score"; return; }
  vec="$(e_vector "$E/$name.sh")"
  printf '  %-10s %s\n' "$name" "$vec"
  diff="$(e_diff "$E_SHIPPED" "$vec")"
  if [ "$name" = "ectl" ]; then
    if [ -n "$diff" ]; then
      bad "CONTROL ectl: an UNMUTATED copy disagreed at [$diff] -- the harness is what moved"
    else
      case "$vec" in
        *PASS/5492/-*) ok "CONTROL ectl: unmutated copy agrees, and DID run (a PASS/5492 row is present)" ;;
        *) bad "CONTROL ectl: agrees but emitted no PASS/5492 row -- two inert runs compare equal" ;;
      esac
    fi
    return
  fi
  for w in "$@"; do
    case " $diff " in
      *" $w "*) ok "KILL $name: killed by $w (all killing worlds: [$diff])" ;;
      *) if [ -n "$diff" ]; then
           bad "KILL $name: $w does not kill it -- killed only at [$diff]"
         else
           bad "KILL $name: SURVIVED every world -- no seed separates it from the shipped selector"
         fi ;;
    esac
  done
}
e_score ectl
e_score pfirst     W-A W-C
e_score plast      W-B W-C
e_score noxcheck   W-D W-D2
e_score body       W-E
e_score oneline    W-F
e_score noprec     W-G
e_score tie        W-I
e_score skipnots   W-J
e_score xcanon     W-K
e_score nohit      W-L W-M
e_score dateabsent W-N
e_score noprior    W-F3
e_score lasthit    W-M

echo ""
if [ "$fails" -eq 0 ]; then
  echo "snapshot-evidence-cell: PASS"
  exit 0
fi
echo "snapshot-evidence-cell: FAIL ($fails assertion(s))"
exit 1
