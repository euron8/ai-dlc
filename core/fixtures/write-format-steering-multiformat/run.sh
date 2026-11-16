#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# write-format-steering-multiformat/run.sh — prove that ONE shared append-only artifact may carry
# MORE THAN ONE declared entry format, that the second one is bound to the right STRING inside the
# right FILE, and that a consumer between two pulls is SKIPPED rather than wedged.
#
# THE DEFECT THIS EXISTS TO CATCH, AND IT IS THE RECEIPT'S, NOT THE VALIDATOR'S. Before this
# change `declared` was a name -> ONE-ENTRY map: a second format under an existing name silently
# replaced the first, so declaring the push-candidate ledger's grammar DELETED the register's
# declaration and the coverage line still read the same. That half is now a list, and a true
# duplicate is keyed on (name, declared_in).
#
# The half that no amount of validator work can reach is the ANCHOR. The validator asks only
# "is this string somewhere in that file", and it CANNOT tell a boundary function's name from any
# other substring the file happens to carry — a sibling function, or a path in the file's own
# header comment. Both are real substrings, both pass, and a declaration pointing at the wrong
# thing reads as covered. What closes that gap is the `:: anchor=<literal>` column `--report` now
# prints, read by a RECEIPT-SHAPED check that compares it literal-equal to the declared anchor.
# The two MUTANT 1 / MUTANT 2 worlds below are that check, and they are the reason this fixture
# exists: they are the worlds in which the validator passes and only the printed anchor column
# separates a wrong anchor from the right one.
#
# SEVEN INDEPENDENT TREES, ONE PROPERTY APART. seed.sh builds each world separately. Sharing one
# tree across two supposedly-different mutants is how two guards come to cover each other, whose
# symptom is ZERO failures rather than two.
#
# EVERY CAPTURE GOES THROUGH A FILE, NEVER A COMMAND SUBSTITUTION. An exit code assigned inside
# `$( )` is lost to a subshell: a `report()` that set an rc variable and was called as
# `OUT="$(report ...)"` left that rc at its initialised value, and three arms then scored a
# correct subject as broken while a fourth passed for the wrong reason. The rc is written to a
# file by the same call that writes the output, and read back from there.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
SEED_ERRF="${TMPDIR:-/tmp}/wfs-mf-seed-err.$$"
SEED_OUT="$(bash "$HERE/seed.sh" 2>"$SEED_ERRF")"; SEED_RC=$?
SEED_ERR="$(cat "$SEED_ERRF" 2>/dev/null)"
rm -f "$SEED_ERRF"

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT, and must report that state as SKIPPED — never as a
# PASS. A consumer whose last pull predates the validator has nothing here to check, and a green
# line from this file would say it checked and found nothing wrong.
if [ "$SEED_RC" -eq 3 ]; then
  echo "write-format-steering-multiformat: SKIPPED — validate-write-format-steering.sh or its"
  echo "  declaration is not on this tree yet (a consumer between two pulls). Nothing was judged."
  fx_skip_exit "$HERE"
fi
[ "$SEED_RC" -eq 0 ] && [ -n "$SEED_OUT" ] || {
  echo "write-format-steering-multiformat: FIXTURE ERROR — seed failed (rc=$SEED_RC): ${SEED_ERR:-<no message>}" >&2
  exit 2; }
WORK="$SEED_OUT"
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
echo "HERMETIC-CONSUMED core/scripts/validate-write-format-steering.sh"

OUTDIR="$WORK/out"
mkdir -p "$OUTDIR" || { echo "write-format-steering-multiformat: FIXTURE ERROR — cannot create the capture area" >&2; exit 2; }

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

echo "write-format-steering-multiformat:"

# --- drive the subject, capturing to FILES ------------------------------------------------------
# Writes $OUTDIR/<tag>.txt (stdout AND stderr — the failing rows go to stderr) and $OUTDIR/<tag>.rc.
# Both layouts, because the consumer worlds have no core/scripts.
drive() {   # <tag> <world-dir>
  local tag="$1" w="$2" script
  if   [ -f "$w/core/scripts/validate-write-format-steering.sh" ]; then
    script="$w/core/scripts/validate-write-format-steering.sh"
  elif [ -f "$w/scripts/ai-dlc/validate-write-format-steering.sh" ]; then
    script="$w/scripts/ai-dlc/validate-write-format-steering.sh"
  else
    printf 'FIXTURE BROKEN: no validator in %s\n' "$w" > "$OUTDIR/$tag.txt"
    printf '99\n' > "$OUTDIR/$tag.rc"
    return 0
  fi
  AI_DLC_PROJECT_ROOT="$w" bash "$script" --report > "$OUTDIR/$tag.txt" 2>&1
  printf '%s\n' "$?" > "$OUTDIR/$tag.rc"
}
rc_of()  { cat "$OUTDIR/$1.rc"; }
txt_of() { printf '%s\n' "$OUTDIR/$1.txt"; }

# THE RECEIPT-SHAPED CHECK. Deliberately the shape a backlog receipt would take — find the row for
# the declared file, pull the `anchor=` field, compare it LITERAL-EQUAL — because the claim under
# test is that such a receipt can now discriminate. Reading the column IS the mechanism; a check
# that merely asserted the ROW exists passes on every anchor mutant below.
receipt_anchor() {   # <capture-file>  -> the anchor literal for the kind=code row, or empty
  awk -v decl="$CODE_DECL" '
    index($0, decl) && index($0, "anchor=") { sub(/^.*anchor=/, ""); print; exit }
  ' "$1"
}

count_in() {   # <capture-file> <fixed-needle>  -> matching line count, 0 on no match
  local n
  n="$(grep -cF "$2" "$1")" || n=0
  printf '%s\n' "$n"
}

has_in() {   # <capture-file> <fixed-needle>  -> 0 if present
  grep -qF "$2" "$1"
}

# ==============================================================================================
# ARM 0 — SANITY. The base world is a real tree and the base run is not a broken one.
# A fixture whose every arm compares two worlds passes identically when the harness itself
# is what failed: two inert runs compare equal. This arm is PRESENCE-shaped on purpose.
# ==============================================================================================
drive base "$W_BASE"
BASE_F="$(txt_of base)"; BASE_RC="$(rc_of base)"
if [ "$BASE_RC" -eq 0 ] && [ -s "$BASE_F" ] && ! has_in "$BASE_F" 'FIXTURE BROKEN'; then
  ok "SANITY: the base world runs and exits 0"
else
  bad "SANITY: the base world did not run cleanly (rc=$BASE_RC) — every verdict below is about a broken harness, not about the subject"
fi

# ==============================================================================================
# ARM 1 — TWO rows for one name. The subject of the schema half of the fix.
# Asserted as a NUMBER, not as "the second row exists": a reader that re-introduced last-write-wins
# would print exactly one row, and an existence check on either row would still find one.
# ==============================================================================================
N_NAME="$(count_in "$BASE_F" "declared   $CODE_NAME ")"
if [ "$N_NAME" -eq 2 ]; then
  ok "one artifact name carries TWO declared-format rows (declared is a LIST, not last-write-wins)"
else
  bad "expected exactly 2 'declared   $CODE_NAME' rows, got $N_NAME — a second format under an existing name was dropped"
fi

# ==============================================================================================
# ARM 2 — the new row resolves to the declared FILE.
# ==============================================================================================
N_DECL="$(count_in "$BASE_F" "$CODE_DECL")"
if [ "$N_DECL" -eq 1 ]; then
  ok "the new row's declared_in is ${CODE_DECL} and resolves in this layout"
else
  bad "expected exactly 1 row naming ${CODE_DECL}, got $N_DECL"
fi

# ==============================================================================================
# ARM 3 — the ANCHOR COLUMN is printed, and it is the declared literal.
# `--report` printing the anchor is what makes a receipt able to bind on the format rather than on
# the filename. Compared literal-equal against the value seed.sh read OUT of the shipped schema —
# this fixture never spells the anchor itself, so it cannot drift into agreeing with a wrong one.
# ==============================================================================================
BASE_ANCHOR="$(receipt_anchor "$BASE_F")"
if [ "$BASE_ANCHOR" = "$CODE_ANCHOR" ]; then
  ok "--report prints the anchor column, and it is the declared literal [$CODE_ANCHOR]"
else
  bad "the anchor column read [${BASE_ANCHOR:-<absent>}], wanted [$CODE_ANCHOR] — a receipt cannot bind on a column that is not there"
fi

# ==============================================================================================
# ARM 4 — COVERAGE IS COUNTED BY DISTINCT NAME, NEVER BY ROW.
# The bash half of the fix. With more OK rows than distinct names, a reader that summed rows would
# print a numerator drawn from outside its denominator's population. Both figures are DERIVED from
# this run's own rows; hard-coding either is how a fixture goes stale silently. The arm REFUSES if
# rows do not exceed names, because with rows == names the two readings agree and prove nothing.
# ==============================================================================================
PASS_LINE_F="$OUTDIR/passline.txt"
grep -F 'PASS —' "$BASE_F" > "$PASS_LINE_F" 2>/dev/null
CLAIMED_COVERED="$(sed -n 's/.*PASS — \([0-9][0-9]*\) of \([0-9][0-9]*\).*/\1/p' "$PASS_LINE_F")"
CLAIMED_POP="$(sed -n 's/.*PASS — \([0-9][0-9]*\) of \([0-9][0-9]*\).*/\2/p' "$PASS_LINE_F")"
NAMES_F="$OUTDIR/names.txt"
awk '/^  declared   /{print $2}' "$BASE_F" | sort -u > "$NAMES_F"
DERIVED_COVERED="$(grep -c . "$NAMES_F")" || DERIVED_COVERED=0
DERIVED_ROWS="$(grep -c '^  declared   ' "$BASE_F")" || DERIVED_ROWS=0
if [ -z "$CLAIMED_COVERED" ] || [ -z "$CLAIMED_POP" ]; then
  bad "no 'PASS — N of M' line to read a coverage figure off"
elif [ "$DERIVED_ROWS" -le "$DERIVED_COVERED" ]; then
  bad "FIXTURE STALE: $DERIVED_ROWS row(s) over $DERIVED_COVERED name(s) — with rows == names a row-summing reader prints the same number and this arm proves nothing"
elif [ "$CLAIMED_COVERED" -eq "$DERIVED_COVERED" ]; then
  ok "the PASS line counts DISTINCT names ($CLAIMED_COVERED of $CLAIMED_POP) over $DERIVED_ROWS rows, not rows"
else
  bad "the PASS line claims $CLAIMED_COVERED covered; distinct names = $DERIVED_COVERED, rows = $DERIVED_ROWS — coverage is being summed over rows"
fi

# ==============================================================================================
# MUTANT 1 — the anchor names a REAL function of the declared file that is NOT the boundary rule.
#
# THE VALIDATOR PASSES, AND THAT IS CORRECT BEHAVIOUR, NOT A DEFECT. It asks only whether the
# string is in the file. Both halves are asserted: the validator's exit is 0 (so an arm keyed on
# the validator's verdict CANNOT see this world — that is the finding), and the receipt-shaped
# check REJECTS it. Asserting only the rejection would leave "the validator caught it too" as an
# explanation, and this arm's whole point is that it does not.
# ==============================================================================================
drive m1 "$W_M1"
M1_F="$(txt_of m1)"; M1_RC="$(rc_of m1)"
M1_READ="$(receipt_anchor "$M1_F")"
if [ "$M1_RC" -eq 0 ]; then
  ok "MUTANT 1 (anchor = another real function of the same file): the VALIDATOR passes — a verdict-keyed check is blind here"
else
  bad "MUTANT 1: the validator exited $M1_RC; this world is a legal declaration by its own rules and must not fail"
fi
if [ -n "$M1_READ" ] && [ "$M1_READ" != "$CODE_ANCHOR" ]; then
  ok "MUTANT 1: the receipt-shaped check REJECTS it (read [$M1_READ], wanted [$CODE_ANCHOR])"
else
  bad "MUTANT 1: the receipt-shaped check read [${M1_READ:-<absent>}] and did not reject — a wrong-substring anchor is indistinguishable from the right one"
fi

# ==============================================================================================
# MUTANT 2 — the anchor is a substring of the declared file's own HEADER COMMENT.
#
# A DIFFERENT WORLD FROM MUTANT 1, not a second spelling of it. M1's anchor is executable text
# that a refactor would move with the code; M2's survives the format being deleted entirely,
# which is the exact failure the schema's own `anchor` description names. Seeded in its own tree,
# from a string derived from the file's header rather than typed here.
# ==============================================================================================
drive m2 "$W_M2"
M2_F="$(txt_of m2)"; M2_RC="$(rc_of m2)"
M2_READ="$(receipt_anchor "$M2_F")"
if [ "$M2_RC" -eq 0 ]; then
  ok "MUTANT 2 (anchor = the file's own header comment): the VALIDATOR passes — a whole-file grep is satisfied by a comment"
else
  bad "MUTANT 2: the validator exited $M2_RC; a present substring is a legal declaration by its own rules"
fi
if [ -n "$M2_READ" ] && [ "$M2_READ" != "$CODE_ANCHOR" ]; then
  ok "MUTANT 2: the receipt-shaped check REJECTS it (read [$M2_READ], wanted [$CODE_ANCHOR])"
else
  bad "MUTANT 2: the receipt-shaped check read [${M2_READ:-<absent>}] and did not reject — a comment-anchored declaration reads as covered"
fi

# ==============================================================================================
# MUTANT 3 — a TRUE duplicate: the same (name, declared_in) pair twice.
#
# The near-miss is the BASE world, which carries two entries under ONE name with DIFFERENT
# declared_in and must stay silent (arm 1 above). Without that pairing this arm cannot tell a
# correctly-keyed duplicate check from one that fires on any repeated name at all — which is
# exactly the behaviour the fix removed.
# ==============================================================================================
drive m3 "$W_M3"
M3_F="$(txt_of m3)"; M3_RC="$(rc_of m3)"
if [ "$M3_RC" -ne 0 ] && has_in "$M3_F" 'same name and declared_in repeated'; then
  ok "MUTANT 3 (same name AND same declared_in twice): FAILS with 'same name and declared_in repeated'"
else
  bad "MUTANT 3: rc=$M3_RC and no 'same name and declared_in repeated' — a copy-paste duplicate is accepted"
fi

# ==============================================================================================
# MUTANT 4 — the SKIP path. Consumer layout, the skills component entirely absent.
#
# install.sh lands core/schemas/, core/scripts/ and core/skills/ as separate pull classes, so a
# consumer between two pulls legitimately has the declaring schema without the file it points at.
# Wedging that consumer's push before it can pull is the shape of check an operator turns off.
# ==============================================================================================
drive m4 "$W_M4"
M4_F="$(txt_of m4)"; M4_RC="$(rc_of m4)"
M4_SKIP=0; grep -qE '^  SKIP ' "$M4_F" && M4_SKIP=1
M4_MISSING=0; has_in "$M4_F" 'and no file is there in any layout' && M4_MISSING=1
if [ "$M4_RC" -eq 0 ] && [ "$M4_SKIP" -eq 1 ] && [ "$M4_MISSING" -eq 0 ]; then
  ok "MUTANT 4 (consumer, skills component absent): exit 0 with a SKIP row, not MISSING — an unpulled component does not wedge the push"
else
  bad "MUTANT 4: rc=$M4_RC skip=$M4_SKIP missing=$M4_MISSING — a consumer between two pulls is being failed for a component it has not pulled"
fi
if has_in "$M4_F" 'not yet present in this layout'; then
  ok "MUTANT 4: the SKIP row SAYS which component is absent, in wording no passing run emits"
else
  bad "MUTANT 4: the SKIP row does not name the absent component — a silent skip reads exactly like a check that ran"
fi

# ==============================================================================================
# MUTANT 5 — the near-miss for MUTANT 4, ONE property apart: the component IS present and the
# declared file is not. A real broken pointer, and it must still FAIL.
#
# This is the arm that makes the SKIP narrowing a discrimination rather than a blanket acquittal.
# Without it, "skip when the file is absent" and "skip when the component is absent" are the same
# passing run, and the second one acquits every stale declaration in the tree.
# ==============================================================================================
drive m5 "$W_M5"
M5_F="$(txt_of m5)"; M5_RC="$(rc_of m5)"
M5_SKIP=0; grep -qE '^  SKIP ' "$M5_F" && M5_SKIP=1
if [ "$M5_RC" -ne 0 ] && [ "$M5_SKIP" -eq 0 ] && has_in "$M5_F" 'and no file is there in any layout'; then
  ok "MUTANT 5 (component PRESENT, declared file absent): FAILS as MISSING — the directory-present/file-absent case still discriminates"
else
  bad "MUTANT 5: rc=$M5_RC skip=$M5_SKIP — a real broken pointer was acquitted as an unpulled component, so the SKIP narrowing acquits everything"
fi

# ==============================================================================================
# MUTANT 6 — the near-miss for MUTANT 5. Same consumer layout, component present, and the declared
# file IS there. Nothing may be reported, and the row must resolve through the CONSUMER spelling.
#
# An arm that flagged this world would flag every correctly-installed consumer, and its finding
# set would be the whole population — a scan that discriminates nothing reads exactly like one
# that discriminates perfectly.
# ==============================================================================================
drive m6 "$W_M6"
M6_F="$(txt_of m6)"; M6_RC="$(rc_of m6)"
M6_READ="$(receipt_anchor "$M6_F")"
if [ "$M6_RC" -eq 0 ] && [ "$M6_READ" = "$CODE_ANCHOR" ]; then
  ok "MUTANT 6 (consumer, component present WITH the declared file): exit 0 and the row resolves through the consumer spelling"
else
  bad "MUTANT 6: rc=$M6_RC anchor=[${M6_READ:-<absent>}] — a correctly-installed consumer is being reported, so MUTANT 5's failure was not about the broken pointer"
fi

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
report_end write-format-steering-multiformat 14
