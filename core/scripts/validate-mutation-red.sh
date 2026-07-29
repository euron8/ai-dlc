#!/usr/bin/env bash
# validate-mutation-red.sh — replay a CLAIMED mutation-red anchor.
#
# Mutate the real source at <target-file>:<line-number>, run the named test, and require
# the transition GREEN -> RED. This is a TRUE mutation-kill replay, never a coverage
# check: a test that reaches the line but does not assert on its value stays GREEN under
# mutation and is reported as unproven, which is the whole point.
#
# WHY CORE SHIPS THIS. Core demands the evidence in four rule files and, until v0.200.0,
# shipped no way to produce or re-check it:
#
#   team-roles/dev.md        "Mutation self-check (mechanical, run BEFORE gate-1
#                            submission)" — revert the guard, run the suite, confirm a
#                            RED, commit the capture plus a byte-identical-restore diff.
#   team-roles/qa.md         "Discriminator mutation-REDs (HARD GATE)" — every
#                            discriminator AC carries a committed mutation-RED artifact.
#   team-roles/code-reviewer.md  the RED evidence must mutate the REAL SUT source that
#                            production imports, not a test-local reimplementation.
#   steps/gate-validation.md the Gate-2 core-path wiring citation names a mutation-RED
#                            wiring test as one of its two acceptable evidences.
#
# All four described a procedure an agent performed by hand and a reviewer graded by
# reading prose. "Ran it, trust me" and a real kill produce the same paragraph.
#
# THE THREE ARMS THAT ARE NOT A VERDICT. An absence is only a finding when something
# proves the search ran. Here the search is the mutation itself, so this script refuses
# to grade a run whose file it did not change:
#
#   - a <line-number> past the end of the file,
#   - a <replacement-line> byte-identical to the line it replaces,
#   - a rewrite that produced no byte change for any other reason.
#
# Each leaves an UNMUTATED file, whose test run is GREEN because nothing happened. The
# reference consumer's implementation collapsed all three into its FAIL arm and printed
# "claimed anchor is unproven" — an accusation against a test that was never put under
# test. (Its rewrite was `sed "<n>s@.*@<repl>@"`, so a replacement containing `@` was a
# fourth instance of the same shape: sed errored, the file stayed put, the verdict line
# still blamed the test.) They exit 2 here, and 2 is not 1.
#
# Usage:
#   validate-mutation-red.sh <target-file> <line-number> <replacement-line> <test-cmd...>
#
# Example — prove the guard at engine.py:42 is what the named test asserts on:
#   scripts/ai-dlc/validate-mutation-red.sh engine.py 42 '    return 3 * x' \
#       python3 -m pytest tests/test_engine.py -q
#
# Exit codes:
#   0  PROVEN       baseline GREEN, the mutation changed bytes, the mutated run went RED,
#                   the file restored byte-identical.
#   1  UNPROVEN     the mutation landed and the named test stayed GREEN — it never
#                   reaches the line, or reaches it without asserting on its value.
#   2  UNEVALUABLE  nothing was tested: usage, unreadable target, no such line, a
#                   no-op replacement, or a baseline that was not GREEN. A claim
#                   graded here is neither proven nor refuted.
#   3  HARD         the restore did not come back byte-identical. The tree is LEFT
#                   MUTATED and the path to the backup is printed. Restore it before
#                   running anything else; every later result is against mutated source.
#
# No git, no schema, no project layout: it takes explicit paths and an explicit command,
# so it runs from any directory, on any language, inside or outside a repository.
#
# bash 3.2+.

set -uo pipefail

# Bytes of a captured run echoed back as evidence. The RED run's tail is what the role
# files ask to be committed; the whole log can be a full suite and belongs in a file.
EVIDENCE_LINES=20

usage() {
  cat <<'EOF'
usage: validate-mutation-red.sh <target-file> <line-number> <replacement-line> <test-cmd...>

  target-file       real source the production path imports (never a test-local copy)
  line-number       1-based line the claim says the named test asserts on
  replacement-line  the mutated line, verbatim, including its indentation
  test-cmd...       the named test, exactly as it is run normally

exit: 0 proven · 1 unproven · 2 unevaluable (nothing was mutated) · 3 restore failed
EOF
}

if [ "$#" -lt 4 ]; then
  usage >&2
  exit 2
fi

TARGET="$1"
LINE="$2"
REPL="$3"
shift 3
TEST_CMD=("$@")

[ -f "$TARGET" ] || { echo "validate-mutation-red: UNEVALUABLE — no such file: $TARGET" >&2; exit 2; }
[ -r "$TARGET" ] || { echo "validate-mutation-red: UNEVALUABLE — unreadable: $TARGET" >&2; exit 2; }
[ -w "$TARGET" ] || { echo "validate-mutation-red: UNEVALUABLE — not writable, a replay must mutate it: $TARGET" >&2; exit 2; }

case "$LINE" in
  ''|*[!0-9]*)
    echo "validate-mutation-red: UNEVALUABLE — line-number must be a positive integer, got '$LINE'" >&2
    exit 2
    ;;
esac
[ "$LINE" -ge 1 ] || { echo "validate-mutation-red: UNEVALUABLE — line-number must be >= 1, got '$LINE'" >&2; exit 2; }

TOTAL="$(awk 'END { print NR }' "$TARGET")"
if [ "$LINE" -gt "$TOTAL" ]; then
  echo "validate-mutation-red: UNEVALUABLE — $TARGET has $TOTAL line(s), so line $LINE cannot be mutated." >&2
  echo "  Nothing was changed, so a GREEN run of the named test says nothing about the claim." >&2
  exit 2
fi

CURRENT="$(awk -v n="$LINE" 'NR == n { print; exit }' "$TARGET")"
if [ "$CURRENT" = "$REPL" ]; then
  echo "validate-mutation-red: UNEVALUABLE — the replacement is the line it replaces:" >&2
  echo "    $TARGET:$LINE  $CURRENT" >&2
  echo "  A mutation that changes nothing cannot kill anything." >&2
  exit 2
fi

BACKUP="$(mktemp)" || { echo "validate-mutation-red: UNEVALUABLE — mktemp failed" >&2; exit 2; }
BASE_LOG="$(mktemp)"
MUT_LOG="$(mktemp)"
MUTANT="$(mktemp)"
cp "$TARGET" "$BACKUP" || { echo "validate-mutation-red: UNEVALUABLE — cannot back up $TARGET" >&2; exit 2; }

# The backup is restored on every exit path, including an interrupt mid-run. The
# explicit restore below is the one that is VERIFIED; this is the net that stops a
# ^C from leaving mutated source behind. The HARD path disarms this trap before it
# exits, which is what keeps $BACKUP on disk for the operator in the one case where
# the working tree still needs it.
restore_trap() {
  cp "$BACKUP" "$TARGET" 2>/dev/null || true
  rm -f "$BACKUP" "$BASE_LOG" "$MUT_LOG" "$MUTANT" 2>/dev/null || true
}
trap restore_trap EXIT INT TERM

# A .pyc whose mtime and size still match the pre-mutation source is reused instead of
# the mutated file, and the mutated run comes back GREEN for a real anchor. Bounded to
# the target's own directory subtree, and __pycache__ is regenerated on the next import.
export PYTHONDONTWRITEBYTECODE=1
clear_pycache() {
  find "$(dirname "$TARGET")" -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
}

evidence() {
  # $1 = label, $2 = log file
  printf '  --- %s (last %s lines) ---\n' "$1" "$EVIDENCE_LINES"
  tail -n "$EVIDENCE_LINES" "$2" | sed 's/^/  | /'
}

# --- baseline: the named test must be GREEN, or there is no transition to observe ----
clear_pycache
"${TEST_CMD[@]}" > "$BASE_LOG" 2>&1
base_rc=$?
if [ "$base_rc" -ne 0 ]; then
  echo "validate-mutation-red: UNEVALUABLE — the named test is not GREEN before the mutation (exit $base_rc)." >&2
  echo "  A GREEN -> RED transition cannot be read off a run that was already RED." >&2
  evidence "baseline run" "$BASE_LOG" >&2
  exit 2
fi

# --- mutate: rewrite line N, then PROVE the file changed --------------------------
# awk with the replacement in the environment, never `-v` (which expands \n and \t) and
# never sed (whose delimiter and & are live in the replacement text).
REPL="$REPL" awk -v n="$LINE" 'NR == n { print ENVIRON["REPL"]; next } { print }' "$BACKUP" > "$MUTANT"
cp "$MUTANT" "$TARGET" || { echo "validate-mutation-red: UNEVALUABLE — cannot write $TARGET" >&2; exit 2; }

if cmp -s "$BACKUP" "$TARGET"; then
  echo "validate-mutation-red: UNEVALUABLE — the rewrite changed no bytes in $TARGET." >&2
  echo "  The file is as it was, so the run below would grade an unmutated tree." >&2
  exit 2
fi

# --- mutated run: PROVEN requires this to go RED -----------------------------------
clear_pycache
"${TEST_CMD[@]}" > "$MUT_LOG" 2>&1
mut_rc=$?

# --- restore, and verify the restore ------------------------------------------------
cp "$BACKUP" "$TARGET" 2>/dev/null
if ! cmp -s "$BACKUP" "$TARGET"; then
  echo "validate-mutation-red: HARD — $TARGET did NOT restore byte-identical." >&2
  echo "  The tree is left MUTATED. The pre-mutation bytes are at: $BACKUP" >&2
  echo "  Restore that file before running anything else; every later result is" >&2
  echo "  measured against mutated source." >&2
  trap - EXIT INT TERM
  rm -f "$BASE_LOG" "$MUT_LOG" "$MUTANT" 2>/dev/null || true
  exit 3
fi

printf 'mutation-red replay\n'
printf '  target:     %s:%s\n' "$TARGET" "$LINE"
printf '  was:        %s\n' "$CURRENT"
printf '  mutated to: %s\n' "$REPL"
printf '  test:       %s\n' "${TEST_CMD[*]}"
printf '  baseline:   GREEN (exit 0)\n'

if [ "$mut_rc" -eq 0 ]; then
  printf '  mutated:    GREEN (exit 0)\n'
  printf '  restore:    byte-identical\n'
  echo "UNPROVEN: $TARGET:$LINE — the named test stayed GREEN under a real mutation." >&2
  echo "  It never reaches that line, or reaches it without asserting on its value" >&2
  echo "  (the coverage-only degenerate). The claimed anchor is not evidence." >&2
  evidence "mutated run" "$MUT_LOG" >&2
  exit 1
fi

printf '  mutated:    RED (exit %s)\n' "$mut_rc"
printf '  restore:    byte-identical\n'
evidence "mutated run" "$MUT_LOG"
printf 'PROVEN: %s:%s reproducibly kills the named test.\n' "$TARGET" "$LINE"
exit 0
