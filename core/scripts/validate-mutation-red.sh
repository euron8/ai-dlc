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
# THE MUTATION THAT LANDS AND BREAKS THE FILE INSTEAD OF THE TEST. A replacement that does
# not parse makes the runner exit non-zero on a COLLECTION error: pytest reports
# `1 error` and a SyntaxError, no test body ran, and a bare `mut_rc != 0` reads that as
# PROVEN. Three arms refuse it, each with exit 2 and a message whose first line names the
# arm, each only after the restore has been verified:
#
#   - parse         automatic for a *.py target when python3 is present: builtin
#                   compile(src, path, "exec") on the baseline and on the mutant. Never
#                   ast.parse, which accepts a module-level `return`; never py_compile,
#                   which writes a .pyc. Refuses only when the baseline compiles and the
#                   mutant does not; otherwise it prints `parse: not checked (<reason>)`.
#   - syntax-check  `--syntax-check '<cmd>'`, for any language: the command is word-split
#                   and run with the target path appended, on the baseline and on the
#                   mutant. Baseline pass and mutant fail refuses; a baseline that fails it
#                   prints `syntax-check: not applied (baseline fails it, exit N)`.
#   - pytest exit   when the test command is pytest (its FIRST word's basename is `pytest`
#                   or `py.test`, or the argv holds `-m pytest`), a mutated exit outside
#                   {0, 1} refuses. Any other runner's exit codes are its own: a non-zero
#                   mutated exit from it is RED, whatever the number.
#                   pytest exits 1 for failed tests and 2-5 for an interrupted run, an
#                   internal error, a usage error or nothing collected.
#
# The parse and syntax checks run on the mutant BEFORE the mutated test run, so a refused
# mutant never runs the suite.
#
# THE RUN THAT EXITS 0 AND RAN NOTHING. pytest exits 0 when every selected test was
# SKIPPED (a `skip` marker, a true `skipif`, a `-k` that keeps only skipped tests), so an
# exit code alone reads such a baseline as GREEN, and the all-skipped mutated run that
# follows as "stayed GREEN under a real mutation". Nothing ran. For a pytest runner this
# script reads pytest's terminal summary line — the LAST line of the form
# `[=== ]<N word>[, <N word>...] in <dur>s[ (h:mm:ss)][ ===]` or `no tests ran in <dur>s`,
# after stripping ANSI colour — and refuses with exit 2, `UNEVALUABLE (no test ran)`, when
# every count word on it is skipped, deselected or warning(s) and at least one is skipped
# or deselected. The predicate is a WHITELIST: any other word (passed, failed, error,
# xfailed, xpassed, a plugin's own) means a test ran and the check stands down. It applies
# to the baseline, where it refuses BEFORE the file is mutated, and to the mutated run,
# where it refuses after the verified restore. A skip-gated test — skipped at baseline,
# its `skipif` flipped by the mutation so the mutated run fails — therefore exits 2, not 0:
# no GREEN -> RED of a test was observed, only RED of a test that never ran GREEN.
# When no summary line can be found the check fails OPEN: it prints
# `skip-check: not applied (no pytest summary line)` on whatever verdict follows.
#
# RESIDUE — WHAT EXIT 0 STILL DOES NOT RULE OUT. "Never PROVEN for an untested mutation"
# is not reachable from an exit code: unittest exits 1 for every failure class, and an
# import inside a test body that raises NameError is `1 failed` in a file that parses
# cleanly. PROVEN can still be printed for a mutation no assertion caught when pytest is
# run through a wrapper — any argv whose first word is not pytest and which holds no
# `-m pytest` (`make test`, `make -C dir pytest`, `tox`, `uv run pytest`),
# when pytest runs with `--continue-on-collection-errors` (exit 1), when the error is a
# runtime error inside a test body, and for a non-Python runner given no `--syntax-check`.
# An ALL-SKIPPED run is read only for pytest: a non-pytest runner (unittest, a wrapper
# around pytest, any other harness) that skips every test and exits 0 still reads GREEN,
# and its mutated run UNPROVEN. Under pytest the skip check is not applied, and the
# `skip-check: not applied` note says so, when the summary line is missing or rewritten:
# `-qq`, `-p no:terminal`, a plugin that rewrites the terminal output, a `--co` run that
# collected nothing (`no tests collected`), or any parser output the script does not
# expect. A `--co` run that collected a test prints `N test(s) collected`, which reads as a
# run, so it stays GREEN under mutation and exits 1 as before. A test pytest counts as
# xfailed may not have run its body: `xfail(run=False)` and an imperative `pytest.xfail()`
# in a fixture both read as a test that ran. Last-match is defeated by output printed
# AFTER pytest's summary (an `atexit` hook that prints a skipped-looking line): that line
# is the one read. A PROVEN carrying the skip-check note does not show the test executed;
# re-run the replay without `-qq`.
# Read the RED evidence the run prints; the exit code is not the whole claim.
#
# Usage:
#   validate-mutation-red.sh [--syntax-check '<cmd>'] [--] <target-file> <line-number> \
#       <replacement-line> <test-cmd...>
#
# Example — prove the guard at engine.py:42 is what the named test asserts on:
#   scripts/ai-dlc/validate-mutation-red.sh engine.py 42 '    return 3 * x' \
#       python3 -m pytest tests/test_engine.py -q
#
# Example — a shell target, where only the caller knows the language's parser:
#   scripts/ai-dlc/validate-mutation-red.sh --syntax-check 'bash -n' lib.sh 7 '  exit 3' \
#       bash tests/lib-test.sh
#
# Exit codes:
#   0  PROVEN       baseline GREEN, the mutation changed bytes, no arm above refused it,
#                   the mutated run went RED, the file restored byte-identical.
#   1  UNPROVEN     the mutation landed and the named test stayed GREEN — it never
#                   reaches the line, or reaches it without asserting on its value.
#   2  UNEVALUABLE  nothing was tested: usage, unreadable target, no such line, a
#                   no-op replacement, a baseline that was not GREEN, a pytest baseline
#                   or mutated run that ran no test (every selected test skipped or
#                   deselected: the no-test-ran arm), or a mutation that landed and
#                   broke the file rather than the test (the parse, syntax-check or
#                   pytest-exit arm). A claim graded here is neither proven nor refuted.
#   3  HARD         the restore did not come back byte-identical. The tree is LEFT
#                   MUTATED and the path to the backup is printed. Restore it before
#                   running anything else; every later result is against mutated source.
#
# No schema, no project layout: it takes explicit paths and an explicit command, so it
# runs from any directory, on any language, inside or outside a repository. Git is read
# only for the capture header's `head:` line, which says so when there is no work tree
# (or no git at all).
#
# bash 3.2+.

set -uo pipefail

# Bytes of a captured run echoed back as evidence. The RED run's tail is what the role
# files ask to be committed; the whole log can be a full suite and belongs in a file.
EVIDENCE_LINES=20

usage() {
  cat <<'EOF'
usage: validate-mutation-red.sh [--syntax-check '<cmd>'] [--] <target-file> <line-number> <replacement-line> <test-cmd...>

  --syntax-check    a parser for the target's language, run with the file path appended,
                    on the baseline and on the mutant (e.g. 'bash -n', 'node --check').
                    Baseline pass and mutant fail exits 2. A *.py target is compiled
                    automatically when python3 is present.
  --                ends the flags; flags are only accepted before the target
  target-file       real source the production path imports (never a test-local copy)
  line-number       1-based line the claim says the named test asserts on
  replacement-line  the mutated line, verbatim, including its indentation
  test-cmd...       the named test, exactly as it is run normally

exit: 0 proven · 1 unproven · 2 unevaluable (nothing was mutated, a pytest baseline or
      mutated run ran no test because every selected test was skipped or deselected, or
      the mutation broke the file rather than the test: it fails to parse, or pytest
      exited outside {0,1}) · 3 restore failed
      Under pytest an all-skipped run is read from pytest's summary line; with no summary
      line (-qq, -p no:terminal) the check prints `skip-check: not applied` and stands down.
EOF
}

# Flags are LEADING only, so a test command's own flags are never read as ours.
SYNTAX_CHECK=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --syntax-check)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "validate-mutation-red: UNEVALUABLE — --syntax-check needs a command" >&2
        usage >&2
        exit 2
      fi
      SYNTAX_CHECK="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    --*)
      echo "validate-mutation-red: UNEVALUABLE — unknown flag: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -lt 4 ]; then
  usage >&2
  exit 2
fi

# Word-split the checker once, here. A value of only whitespace splits to NO words, and an
# empty array expansion is an error under set -u on bash 3.2, so it is refused as usage.
SC_ARGV=()
if [ -n "$SYNTAX_CHECK" ]; then
  read -r -a SC_ARGV <<<"$SYNTAX_CHECK"
  if [ "${#SC_ARGV[@]}" -eq 0 ]; then
    echo "validate-mutation-red: UNEVALUABLE — --syntax-check needs a command, got only whitespace" >&2
    usage >&2
    exit 2
  fi
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
CHECK_LOG="$(mktemp)"
cp "$TARGET" "$BACKUP" || { echo "validate-mutation-red: UNEVALUABLE — cannot back up $TARGET" >&2; exit 2; }

# The backup is restored on every exit path, including an interrupt mid-run. The
# explicit restore below is the one that is VERIFIED; this is the net that stops a
# ^C from leaving mutated source behind. The HARD path disarms this trap before it
# exits, which is what keeps $BACKUP on disk for the operator in the one case where
# the working tree still needs it.
restore_trap() {
  cp "$BACKUP" "$TARGET" 2>/dev/null || true
  rm -f "$BACKUP" "$BASE_LOG" "$MUT_LOG" "$MUTANT" "$CHECK_LOG" 2>/dev/null || true
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
  # LC_ALL=C: a log carrying a non-UTF-8 byte is `illegal byte sequence` to a UTF-8 sed.
  tail -n "$EVIDENCE_LINES" "$2" | LC_ALL=C sed 's/^/  | /'
}

# --- the two differential parse checks. $2 is a label only; it keeps the baseline and
# mutant invocations on distinct lines. Output goes to $CHECK_LOG for the refusal.
py_compiles() {
  # $1 = file, $2 = baseline|mutant
  python3 -c 'import sys; compile(open(sys.argv[1], "rb").read(), sys.argv[1], "exec")' "$1" > "$CHECK_LOG" 2>&1
}
syntax_checks() {
  # $1 = file, $2 = baseline|mutant. Only called when SYNTAX_CHECK is set, and the flag
  # parse above refused a value that splits to no words, so SC_ARGV is non-empty.
  "${SC_ARGV[@]}" "$1" > "$CHECK_LOG" 2>&1
}

# pytest exits 1 for failed tests and 2-5 for everything that is not a test failure.
# Detection is ANCHORED: the FIRST word's basename is pytest or py.test, or the argv holds
# `-m pytest` with the word after `-m` exactly `pytest`. A later bare `pytest` word is an
# argument to some other program (`make -C dir pytest`) whose exit codes are its own.
IS_PYTEST=0
case "${TEST_CMD[0]##*/}" in
  pytest|py.test|pytest-[0-9]*|py.test-[0-9]*) IS_PYTEST=1 ;;
esac
prev_word=""
for word in "${TEST_CMD[@]}"; do
  if [ "$word" = "-mpytest" ] || { [ "$prev_word" = "-m" ] && [ "$word" = "pytest" ]; }; then
    IS_PYTEST=1
  fi
  prev_word="$word"
done

# pytest's summary line, read from a captured log in ONE awk pass: strip ANSI colour, keep
# the LAST line matching the summary grammar (a test run with -s can print a fake one
# earlier), then classify its count words against a WHITELIST. Prints exactly one word:
#   none   no summary line found (-qq, -p no:terminal, rewritten output): fail open
#   norun  every count word is skipped/deselected/warning(s), at least one skipped or
#          deselected, or the line is `no tests ran`
#   ran    any other word (passed, failed, error, xfailed, xpassed, a plugin word)
# LC_ALL=C: under a UTF-8 locale /usr/bin/awk ABORTS on a non-UTF-8 byte in the log
# (`towc: multibyte conversion failure`, exit 2, no output). Every caller also treats any
# output other than these three words as `none`, so a parser that dies fails open and says so.
pytest_summary() {
  # $1 = log file
  LC_ALL=C awk '
    BEGIN { esc = sprintf("%c", 27); last = "" }
    {
      line = $0
      gsub(esc "\\[[0-9;]*m", "", line)
      gsub(/\r/, "", line)
      sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line)
      if (line ~ /^(=+ )?(no tests ran|[0-9]+ [a-z]+( [a-z]+)*(, [0-9]+ [a-z]+( [a-z]+)*)*) in [0-9]+(\.[0-9]+)?s( \([0-9]+:[0-9]+:[0-9]+\))?( =+)?$/)
        last = line
    }
    END {
      if (last == "") { print "none"; exit }
      sub(/^=+ /, "", last); sub(/ =+$/, "", last); sub(/ in [0-9]+(\.[0-9]+)?s.*$/, "", last)
      if (last == "no tests ran") { print "norun"; exit }
      n = split(last, part, ", ")
      ran = 0; idle = 0
      for (i = 1; i <= n; i++) {
        word = part[i]; sub(/^[0-9]+ /, "", word)
        if (word == "skipped" || word == "deselected") idle = 1
        else if (word != "warning" && word != "warnings") ran = 1
      }
      print ((ran == 0 && idle == 1) ? "norun" : "ran")
    }
  ' "$1"
}
SKIP_NOTE=""
SKIP_NOTE_TEXT="skip-check: not applied (no pytest summary line)"

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

# --- baseline skip check: an exit 0 in which pytest ran no test is not GREEN -----------
# Refused here, BEFORE the mutation, so the target is never touched.
if [ "$IS_PYTEST" -eq 1 ]; then
  case "$(pytest_summary "$BASE_LOG")" in
    norun)
      echo "validate-mutation-red: UNEVALUABLE (no test ran) — the baseline is not GREEN: it ran no test (every selected test was skipped or deselected)." >&2
      echo "  pytest exits 0 when it skips everything, so the exit code reads GREEN over a run" >&2
      echo "  that put nothing under test. Nothing was mutated." >&2
      evidence "baseline run" "$BASE_LOG" >&2
      exit 2
      ;;
    ran) ;;
    *) SKIP_NOTE="$SKIP_NOTE_TEXT" ;;
  esac
fi

# --- baseline parse checks: an arm applies only where the UNMUTATED file passes it ----
PARSE_ARM=0
PARSE_NOTE=""
case "$TARGET" in
  *.py)
    if ! command -v python3 >/dev/null 2>&1; then
      PARSE_NOTE="parse: not checked (python3 not found)"
    elif py_compiles "$TARGET" baseline; then
      PARSE_ARM=1
    else
      PARSE_NOTE="parse: not checked (baseline does not compile)"
    fi
    ;;
esac
SC_ARM=0
SC_NOTE=""
if [ -n "$SYNTAX_CHECK" ]; then
  if syntax_checks "$TARGET" baseline; then
    SC_ARM=1
  else
    SC_NOTE="syntax-check: not applied (baseline fails it, exit $?)"
  fi
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

# --- mutant parse checks, BEFORE the mutated run: a mutant that does not parse is never
# run, because whatever the runner exits on it, no test body was put under test. -------
REFUSED=""
if [ "$PARSE_ARM" -eq 1 ] && ! py_compiles "$TARGET" mutant; then
  REFUSED="parse"
elif [ "$SC_ARM" -eq 1 ] && ! syntax_checks "$TARGET" mutant; then
  REFUSED="syntax-check"
fi

# --- mutated run: PROVEN requires this to go RED -----------------------------------
mut_rc=0
if [ -z "$REFUSED" ]; then
  clear_pycache
  "${TEST_CMD[@]}" > "$MUT_LOG" 2>&1
  mut_rc=$?
fi

# --- mutated skip check: a mutated run that ran no test is neither a kill nor a survival.
# Read here, refused below only after the verified restore.
MUT_NORUN=0
if [ -z "$REFUSED" ] && [ "$IS_PYTEST" -eq 1 ]; then
  case "$(pytest_summary "$MUT_LOG")" in
    norun) MUT_NORUN=1 ;;
    ran)   ;;
    *)     SKIP_NOTE="$SKIP_NOTE_TEXT" ;;
  esac
fi

# --- restore, and verify the restore ------------------------------------------------
cp "$BACKUP" "$TARGET" 2>/dev/null
if ! cmp -s "$BACKUP" "$TARGET"; then
  echo "validate-mutation-red: HARD — $TARGET did NOT restore byte-identical." >&2
  echo "  The tree is left MUTATED. The pre-mutation bytes are at: $BACKUP" >&2
  echo "  Restore that file before running anything else; every later result is" >&2
  echo "  measured against mutated source." >&2
  trap - EXIT INT TERM
  rm -f "$BASE_LOG" "$MUT_LOG" "$MUTANT" "$CHECK_LOG" 2>/dev/null || true
  exit 3
fi

printf 'mutation-red replay\n'
# head and cwd make a committed capture checkable against the commit it claims to grade
# (validate-handoff-evidence.sh reads `head:`). Outside a git work tree the line still
# prints, so a capture's shape does not depend on where it was taken.
HEAD_SHA="$(git -C "$(dirname "$TARGET")" rev-parse HEAD 2>/dev/null)" || HEAD_SHA=""
printf '  head:       %s\n' "${HEAD_SHA:-(not a git work tree)}"
printf '  cwd:        %s\n' "$PWD"
printf '  target:     %s:%s\n' "$TARGET" "$LINE"
printf '  was:        %s\n' "$CURRENT"
printf '  mutated to: %s\n' "$REPL"
printf '  test:       %s\n' "${TEST_CMD[*]}"
printf '  baseline:   GREEN (exit 0)\n'
[ -z "$PARSE_NOTE" ] || printf '  %s\n' "$PARSE_NOTE"
[ -z "$SC_NOTE" ] || printf '  %s\n' "$SC_NOTE"
[ -z "$SKIP_NOTE" ] || printf '  %s\n' "$SKIP_NOTE"

# Every refusal below is printed only after the restore above was VERIFIED.
if [ "$REFUSED" = "parse" ]; then
  printf '  mutated:    not run (the mutant does not compile)\n'
  printf '  restore:    byte-identical\n'
  echo "validate-mutation-red: UNEVALUABLE (parse) — the baseline compiles and the mutated $TARGET does not." >&2
  echo "  A runner exits non-zero on a collection error before any test body runs, so a RED" >&2
  echo "  here would grade a broken file, not the named test." >&2
  evidence "compile of the mutant" "$CHECK_LOG" >&2
  exit 2
fi
if [ "$REFUSED" = "syntax-check" ]; then
  printf '  mutated:    not run (the mutant fails --syntax-check)\n'
  printf '  restore:    byte-identical\n'
  echo "validate-mutation-red: UNEVALUABLE (syntax-check) — '$SYNTAX_CHECK' passes the baseline and fails the mutated $TARGET." >&2
  echo "  A mutant that does not parse is not a claim about the named test." >&2
  evidence "syntax-check of the mutant" "$CHECK_LOG" >&2
  exit 2
fi
if [ "$MUT_NORUN" -eq 1 ]; then
  printf '  mutated:    exit %s, ran no test (every selected test was skipped or deselected)\n' "$mut_rc"
  printf '  restore:    byte-identical\n'
  echo "validate-mutation-red: UNEVALUABLE (no test ran) — the mutated run ran no test (every selected test was skipped or deselected)." >&2
  echo "  The mutation changed what pytest selects or skips, so neither a GREEN nor a RED here" >&2
  echo "  is a claim about the named test's assertion." >&2
  evidence "mutated run" "$MUT_LOG" >&2
  exit 2
fi

if [ "$mut_rc" -eq 0 ]; then
  printf '  mutated:    GREEN (exit 0)\n'
  printf '  restore:    byte-identical\n'
  echo "UNPROVEN: $TARGET:$LINE — the named test stayed GREEN under a real mutation." >&2
  echo "  It never reaches that line, or reaches it without asserting on its value" >&2
  echo "  (the coverage-only degenerate). The claimed anchor is not evidence." >&2
  evidence "mutated run" "$MUT_LOG" >&2
  exit 1
fi

if [ "$IS_PYTEST" -eq 1 ] && [ "$mut_rc" -ne 1 ]; then
  printf '  mutated:    exit %s (not a pytest test failure)\n' "$mut_rc"
  printf '  restore:    byte-identical\n'
  echo "validate-mutation-red: UNEVALUABLE (pytest exit) — the mutated run exited $mut_rc, and pytest exits 1 for failed tests." >&2
  echo "  2-5 is an interrupted run, an internal error, a usage error or nothing collected" >&2
  echo "  (a collection error is 2): no assertion in the named test went RED." >&2
  evidence "mutated run" "$MUT_LOG" >&2
  exit 2
fi

printf '  mutated:    RED (exit %s)\n' "$mut_rc"
printf '  restore:    byte-identical\n'
evidence "mutated run" "$MUT_LOG"
printf 'PROVEN: %s:%s reproducibly kills the named test.\n' "$TARGET" "$LINE"
exit 0
