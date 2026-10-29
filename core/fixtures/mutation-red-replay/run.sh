#!/usr/bin/env bash
# mutation-red-replay — prove `validate-mutation-red.sh` grades a claim only when it
# actually mutated something, and says which of the four outcomes it reached.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH. The replay's whole verdict is an absence — the named
# test did NOT go red — and an absence is only a finding when something proves the search
# ran. Here the search IS the mutation. The reference consumer's implementation graded
# three unmutated files as failed anchors: a line past the end of the file, a replacement
# identical to the line it replaces, and a replacement containing its `sed` delimiter all
# left the source untouched, and all three printed "claimed anchor is unproven" — an
# accusation against a test that was never put under test. That is this repo's named class
# with the polarity flipped: the check could not fire, and its silence was rendered as a
# finding rather than as a pass.
#
# So the assertions below are about the SPLIT, not about today's messages. Exit 1 must
# mean "the mutation landed and the test survived it" and nothing else; exit 2 must be
# reachable from every path that leaves the file as it was; exit 3 must be reachable when
# the file does not come back.
#
# NOT COVERED, deliberately: the stale-bytecode guard (PYTHONDONTWRITEBYTECODE plus the
# __pycache__ clear). Reproducing a reused .pyc needs a mutation whose size and mtime
# match the original by construction, which is a timing race, not a fixture. The guard is
# carried on the reference consumer's measurement, and this file does not claim it.
#
# THE MUTANT BATTERY IS SCORED PER PUSH ON A SUBSET. Every mutant is a copy of the validator with
# one fault. Each arm below is a function of the validator it is handed: it holds (returns 0) or it
# fails and sets $why. The live pass drives every arm against the SHIPPED validator, so the base
# coverage is whole. Per push a mutant then runs only its DECIDING arm (which must FAIL on the copy)
# and its TWIN (an arm that PASSES on the copy, one property apart, so the deciding arm is shown to
# read the fault and not to fail everything). The rows below are read BY THIS FILE at run time
# (score_mutant parses its own header), so the header and the scoring cannot drift apart, and a
# mutant with no row is a FIXTURE BROKEN, never a silent skip.
#
# --matrix (argv) prints one `MATRIX<TAB><mutant><TAB><arm><TAB><FAIL|ok>` line per mutant x arm
# cell: FAIL = the arm fails on the mutant's copy, ok = it holds. Cells that FAIL beyond the
# decides= arm are listed in the comment above the rows, not in decides=.
# Cells that FAIL beyond the decides= arm (measured, listed here and not in decides=): m2 also rt_H; m4 also marker_refused;
# m7 and m8 also py_return and py_marker; m9 also s9; m10 also later_pytest_word; m12 also py_marker; m15 also rt_T, rt_X, rt_D;
# m16 also rt_Q, rt_control, rt_U, rt_T, rt_X, rt_D; m18 also rt_H; m20 also rt_X; sk1 and sk9 also stub_note, s1-s4, s7-s9b and s11
# (sk9 also parser_dead is its decider); sk3 none; sk4 also pytest_exit5, pytest_exit2, pytest_stub_kill, dash_m_pytest, stub_note,
# parser_dead, s9b; sk7 also s3.
# MUTANT-MATRIX m1 decides=a2_noop twins=a3_eof
# MUTANT-MATRIX m2 decides=a7_hard twins=a4_red
# MUTANT-MATRIX m3 decides=amp twins=a5_special
# MUTANT-MATRIX m4 decides=a8_syntax twins=a9_syntaxkill
# MUTANT-MATRIX m5 decides=py_return twins=py_syntax
# MUTANT-MATRIX m6 decides=py_badbase twins=py_syntax
# MUTANT-MATRIX m7 decides=py_syntax twins=py_badbase
# MUTANT-MATRIX m8 decides=py_syntax twins=py_badbase
# MUTANT-MATRIX m9 decides=pytest_green twins=pytest_collect
# MUTANT-MATRIX m10 decides=nonpytest_exit2 twins=pytest_exit5
# MUTANT-MATRIX m11 decides=pytest_exit5 twins=pytest_exit2
# MUTANT-MATRIX m12 decides=marker_refused twins=marker_control
# MUTANT-MATRIX m13 decides=later_pytest_word twins=pytest_stub_kill
# MUTANT-MATRIX m14 decides=ws_syntax_check twins=marker_control
# MUTANT-MATRIX m15 decides=rt_A twins=rt_Q
# MUTANT-MATRIX m16 decides=rt_A twins=rt_R
# MUTANT-MATRIX m17 decides=rt_A twins=rt_Q
# MUTANT-MATRIX m18 decides=rt_R twins=rt_A
# MUTANT-MATRIX m19 decides=rt_H twins=rt_R
# MUTANT-MATRIX m20 decides=rt_T twins=rt_A
# MUTANT-MATRIX m21 decides=rt_X twins=rt_T
# MUTANT-MATRIX m22 decides=rt_D twins=rt_X
# MUTANT-MATRIX m23 decides=rt_E twins=rt_A
# MUTANT-MATRIX sk1 decides=s1 twins=s5
# MUTANT-MATRIX sk2 decides=s5 twins=s1
# MUTANT-MATRIX sk3 decides=s7 twins=s1
# MUTANT-MATRIX sk4 decides=s9 twins=s1
# MUTANT-MATRIX sk5 decides=s6 twins=s1
# MUTANT-MATRIX sk6 decides=s4 twins=s1
# MUTANT-MATRIX sk7 decides=s2 twins=s1
# MUTANT-MATRIX sk8 decides=s11 twins=s1
# MUTANT-MATRIX sk9 decides=parser_dead twins=pytest_stub_kill
# MUTANT-MATRIX-DYNAMIC score-mutant why=score_mutant passes its first argument "$m" to mutant_killed; the loop over MUTS names only literal mutants m1-m23 and sk1-sk9, each carrying its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/mutation-red-replay/run.sh --matrix
# The matrix is re-measured whenever an arm or a mutant is added or changed.
#
# NOT COVERED, deliberately: the stale-bytecode guard (PYTHONDONTWRITEBYTECODE plus the
# __pycache__ clear). Reproducing a reused .pyc needs a mutation whose size and mtime
# match the original by construction, which is a timing race, not a fixture. The guard is
# carried on the reference consumer's measurement, and this file does not claim it.
set -uo pipefail

MATRIX=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; shift; fi
MATRIX_CELLS=0

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
echo "HERMETIC-CONSUMED $VALIDATOR"
[ "$MATRIX" -eq 0 ] || echo "MATRIX-MODE on"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
skip() { printf '  SKIP  %s\n' "$1"; }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# shellcheck source=/dev/null
. "$MUT_LIB"

MUTATED="value() { printf '99\n'; }"   # a real change to line 2's value
SUT="$WORK/sut.sh"
BEFORE="$(cksum < "$SUT")"
cp "$SUT" "$WORK/sut.orig"

# replay <validator> <line> <replacement> <test> -> sets $rc and $out
replay() {
  local v="$1" line="$2" repl="$3" test="$4"
  out="$(bash "$v" "$SUT" "$line" "$repl" bash "$test" 2>&1)"
  rc=$?
}
# vrun <validator> <args...> -> sets $rc and $out (stdout and stderr together)
vrun() {
  local v="$1"; shift
  out="$(bash "$v" "$@" 2>&1)"
  rc=$?
}
SH_BROKEN='value() {'                       # does not parse: bash -n fails, the run fails
SH_KILL="value() { printf '9\n'; }"         # parses, and kills disc.sh

lines_of() { [ -f "$1" ] && awk 'END { print NR }' "$1" || echo 0; }

arm_nonpytest_exit2() {  # a NON-pytest runner exiting 2 on a real kill -> 0, PROVEN
  vrun "$1" "$SUT" 2 "$SH_KILL" bash "$WORK/disc2.sh"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out" && grep -q '^  mutated:    RED (exit 2)$' <<<"$out"
}
arm_pytest_exit5() {     # a stub named pytest exiting 5 -> 2, with a verified restore
  vrun "$1" "$SUT" 2 five "$WORK/bin/pytest"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (pytest exit)' <<<"$out" \
    && grep -q '^  restore:    byte-identical$' <<<"$out" && [ "$(cksum < "$SUT")" = "$BEFORE" ]
}
arm_pytest_exit2() {     # the same stub exiting 2 -> 2 (the near-miss a refuse-only-2 fix keeps)
  vrun "$1" "$SUT" 2 bomb "$WORK/bin/pytest"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (pytest exit)' <<<"$out"
}
arm_pytest_stub_kill() { # the same stub exiting 1 -> 0, so the stub is a working pytest
  vrun "$1" "$SUT" 2 "$SH_KILL" "$WORK/bin/pytest"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out"
}
arm_later_pytest_word() { # make-style argv, `pytest` a LATER word, real kill exits 2 -> 0
  vrun "$1" "$SUT" 2 "$SH_KILL" bash "$WORK/disc2.sh" -C "$WORK" pytest
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out"
}
arm_dash_m_pytest() {    # the ALLOW twin: the same runner with a `-m pytest` pair -> 2
  vrun "$1" "$SUT" 2 "$SH_KILL" bash "$WORK/disc2.sh" -m pytest
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (pytest exit)' <<<"$out"
}
arm_marker_refused() {   # a syntax-check refusal runs the suite ONCE (the baseline) only
  rm -f "$WORK/marker"
  vrun "$1" --syntax-check 'bash -n' "$SUT" 2 "$SH_BROKEN" bash "$WORK/marked.sh"
  why="exit $rc, $(lines_of "$WORK/marker") run(s)"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (syntax-check)' <<<"$out" && [ "$(lines_of "$WORK/marker")" -eq 1 ]
}
arm_marker_control() {   # the marker counts the mutated run: a parsing kill shows 2 runs
  rm -f "$WORK/marker"
  vrun "$1" --syntax-check 'bash -n' "$SUT" 2 "$SH_KILL" bash "$WORK/marked.sh"
  why="exit $rc, $(lines_of "$WORK/marker") run(s)"
  [ "$rc" -eq 0 ] && [ "$(lines_of "$WORK/marker")" -eq 2 ]
}
arm_ws_syntax_check() {  # --syntax-check of only whitespace -> 2 as usage, target untouched
  vrun "$1" --syntax-check ' ' "$SUT" 2 "$SH_KILL" bash "$WORK/disc.sh"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'needs a command' <<<"$out" && [ "$(cksum < "$SUT")" = "$BEFORE" ]
}

# --- the arms of assertions 1-5, 7-9 and the replacement-is-data mutant, as functions ---------
arm_a1_unproven() {  # the coverage-only degenerate: exit 1
  replay "$1" 2 "$MUTATED" "$WORK/nondisc.sh"
  why="exit $rc"
  [ "$rc" -eq 1 ] && grep -q 'stayed GREEN under a real mutation' <<<"$out"
}
arm_a2_noop() {      # a replacement identical to its line: exit 2, not 1
  replay "$1" 2 "value() { printf '42\n'; }" "$WORK/disc.sh"
  why="exit $rc"
  [ "$rc" -eq 2 ]
}
arm_a3_eof() {       # a line past the end of the file: exit 2
  replay "$1" 99 "$MUTATED" "$WORK/disc.sh"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'cannot be mutated' <<<"$out"
}
arm_a4_red() {       # a baseline that is already RED: exit 2
  replay "$1" 2 "$MUTATED" "$WORK/red.sh"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'not GREEN before the mutation' <<<"$out"
}
arm_a5_special() {   # @, & and a backslash in the replacement all mutate and kill
  local special bad_n=0
  for special in 'value() { printf "9@9\n"; }' 'value() { printf "9&9\n"; }' 'value() { printf "9\\19\n"; }'; do
    replay "$1" 2 "$special" "$WORK/disc.sh"
    [ "$rc" -eq 0 ] || bad_n=1
  done
  why="a rewriter-special replacement did not mutate (last exit $rc)"
  [ "$bad_n" -eq 0 ]
}
arm_a7_hard() {      # a restore that does not verify: exit 3, backup path printed and intact
  local bkp
  rm -rf "$WORK/hard"; mkdir -p "$WORK/hard"; cp "$SUT" "$WORK/hard/sut.sh"; printf '0\n' > "$WORK/hard-count"
  vrun "$1" "$WORK/hard/sut.sh" 2 "$MUTATED" bash "$WORK/hard-test.sh"
  why="exit $rc"
  [ "$rc" -eq 3 ] || return 1
  bkp="$(printf '%s\n' "$out" | sed -n 's@.*pre-mutation bytes are at: @@p')"
  why="exit 3 but the printed backup path does not hold the pre-mutation bytes"
  [ -n "$bkp" ] && [ -f "$bkp" ] && [ "$(cksum < "$bkp")" = "$BEFORE" ]
}
arm_a8_syntax() {    # --syntax-check refuses a non-parsing mutant (PROVEN without the flag)
  local noflag
  vrun "$1" "$SUT" 2 "$SH_BROKEN" bash "$WORK/disc.sh"
  noflag="$rc"
  vrun "$1" --syntax-check 'bash -n' "$SUT" 2 "$SH_BROKEN" bash "$WORK/disc.sh"
  why="exit $rc (without the flag: $noflag)"
  [ "$noflag" -eq 0 ] && [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (syntax-check)' <<<"$out" \
    && grep -q '^  restore:    byte-identical$' <<<"$out"
}
arm_a9_syntaxkill() { # the same flag leaves a parsing kill PROVEN
  vrun "$1" --syntax-check 'bash -n' -- "$SUT" 2 "$SH_KILL" bash "$WORK/disc.sh"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out"
}
arm_amp() {          # a replacement of '&' is a literal to the shipped rewrite: exit 0
  replay "$1" 2 '&' "$WORK/disc.sh"
  why="exit $rc"
  [ "$rc" -eq 0 ]
}

# --- Python worlds. Built here, not in seed.sh, so the shell arms above need nothing. ---
# pyworld <name> <m.py body> -> echoes a dir holding m.py, a plain runner t.py and a
# pytest file test_m.py. All three runners are absolute-path, so no arm depends on cwd.
pyworld() {
  local d="$WORK/py-$1"
  mkdir -p "$d"
  printf '%b' "$2" > "$d/m.py"
  printf 'import sys\nsys.path.insert(0, %s)\nimport m\nsys.exit(0 if m.f() == 2 else 1)\n' "'$d'" > "$d/t.py"
  printf 'from m import f\ndef test_f():\n    assert f() == 2\n' > "$d/test_m.py"
  printf '%s\n' "$d"
}
HAVE_PY=0; command -v python3 >/dev/null 2>&1 && HAVE_PY=1
HAVE_PYTEST=0
[ "$HAVE_PY" -eq 1 ] && python3 -c 'import pytest' >/dev/null 2>&1 && HAVE_PYTEST=1
PYTEST=(python3 -m pytest -q -p no:cacheprovider)
skip() { printf '  SKIP  %s\n' "$1"; }

# Each python arm is a function of the validator, so the mutants below drive the same arm.
# Each prints nothing and returns 0 when it holds, else sets $why and returns 1.
arm_py_syntax() {   # a syntax error on a .py target -> 2, restore printed AND on disk
  local d before; d="$(pyworld "syntax-$2" 'def f():\n    return 2\n')"; before="$(cksum < "$d/m.py")"
  vrun "$1" "$d/m.py" 1 'def f(:' python3 "$d/t.py"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (parse)' <<<"$out" \
    && grep -q '^  restore:    byte-identical$' <<<"$out" \
    && [ "$(cksum < "$d/m.py")" = "$before" ]
}
arm_py_return() {   # module-level `return 1`: ast.parse accepts it, compile() does not
  local d; d="$(pyworld "return-$2" 'X = 1\ndef f():\n    return 2\n')"
  vrun "$1" "$d/m.py" 1 'return 1' python3 "$d/t.py"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (parse)' <<<"$out"
}
arm_py_badbase() {  # baseline does not compile, killing mutation -> 0, never 2
  local d; d="$(pyworld "badbase-$2" 'def f(:\nVALUE = 2\n')"
  vrun "$1" "$d/m.py" 2 'VALUE = 3' grep -q 'VALUE = 2' "$d/m.py"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q 'parse: not checked (baseline does not compile)' <<<"$out" \
    && grep -q '^PROVEN:' <<<"$out"
}
arm_pytest_collect() {  # compiles, import fails at module top level: pytest exit 2 -> 2
  local d; d="$(pyworld "collect-$2" 'X = 1\ndef f():\n    return 2\n')"
  vrun "$1" "$d/m.py" 1 'raise ImportError("boom")' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (pytest exit)' <<<"$out"
}
arm_pytest_green() {    # coverage-only pytest test, mutated run exit 0 -> 1 (UNPROVEN), not 2
  local d; d="$(pyworld "green-$2" 'def f():\n    return 2\n')"
  printf 'from m import f\ndef test_f():\n    f()\n' > "$d/test_m.py"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 1 ] && grep -q 'stayed GREEN under a real mutation' <<<"$out"
}
arm_pytest_kill() {     # an assertion failure under pytest (exit 1) -> 0, PROVEN
  local d; d="$(pyworld "kill-$2" 'def f():\n    return 2\n')"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out"
}

arm_py_marker() {   # a parse refusal never runs the suite: the marker shows the baseline run only
  local pmd; pmd="$(pyworld "marker-$2" 'def f():\n    return 2\n')"; rm -f "$WORK/pmarker"
  vrun "$1" "$pmd/m.py" 1 'def f(:' bash -c 'printf "run\n" >> "$1"; python3 "$2"' marker "$WORK/pmarker" "$pmd/t.py"
  why="exit $rc, $(lines_of "$WORK/pmarker") run(s)"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (parse)' <<<"$out" && [ "$(lines_of "$WORK/pmarker")" -eq 1 ]
}

PYTEST_QQ=(python3 -m pytest -qq -p no:cacheprovider)
SKIP_NOTE_LINE='^  skip-check: not applied (no pytest summary line)$'

# skworld <name> <m.py body> <test_m.py body> -> echoes the world dir
skworld() {
  local d; d="$(pyworld "$1" "$2")"
  printf '%b' "$3" > "$d/test_m.py"
  printf '%s\n' "$d"
}
T_SKIP='import pytest\nfrom m import f\n@pytest.mark.skip(reason="x")\ndef test_f():\n    assert f() == 2\n'
T_MIXED='import pytest\nfrom m import f\n@pytest.mark.skip(reason="x")\ndef test_a():\n    assert f() == 2\ndef test_b():\n    assert f() == 2\n'
M_F='def f():\n    return 2\n'

arm_s1() {  # @pytest.mark.skip only -> 2 before any mutation, target byte-identical
  local d before; d="$(skworld "s1-$2" "$M_F" "$T_SKIP")"; cp "$d/m.py" "$d/m.orig"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran) — the baseline is not GREEN: it ran no test' <<<"$out" \
    && cmp -s "$d/m.py" "$d/m.orig" && ! grep -q '^mutation-red replay$' <<<"$out"
}
arm_s2() {  # -k keeps only the skipped test: rc 0, `1 skipped, 1 deselected` -> 2
  local d; d="$(skworld "s2-$2" "$M_F" "$T_MIXED")"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" "$d/test_m.py" -k test_a
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran)' <<<"$out"
}
arm_s3() {  # `1 skipped, 1 warning` -> 2 (a warning is not a test that ran)
  local d; d="$(skworld "s3-$2" "$M_F" 'import warnings, pytest\nfrom m import f\nwarnings.warn("module warn")\n@pytest.mark.skip(reason="x")\ndef test_f():\n    assert f() == 2\n')"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran)' <<<"$out" && grep -q '1 skipped, 1 warning in' <<<"$out"
}
arm_s4() {  # PY_COLORS=1: the summary line is wrapped in ANSI escapes -> still 2
  local d; d="$(skworld "s4-$2" "$M_F" "$T_SKIP")"
  vrun "$1" "$d/m.py" 2 '    return 3' env PY_COLORS=1 "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran)' <<<"$out" && grep -q "$(printf '\033')" <<<"$out"
}
arm_s5() {  # one skipped and one passing test, a real kill -> 0 (a test ran)
  local d; d="$(skworld "s5-$2" "$M_F" "$T_MIXED")"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out"
}
arm_s6() {  # a -s test PRINTS a fake all-skipped summary, then really passes: LAST match wins -> 0
  local d; d="$(skworld "s6-$2" "$M_F" 'from m import f\ndef test_f():\n    print("1 skipped in 0.00s")\n    assert f() == 2\n')"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" -s "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out"
}
arm_s7() {  # the mutation flips a skipif: baseline ran, mutated run skipped all -> 2 after restore
  local d before
  d="$(skworld "s7-$2" 'ENABLED = True\ndef f():\n    return 2\n' 'import pytest\nimport m\n@pytest.mark.skipif(not m.ENABLED, reason="off")\ndef test_f():\n    assert m.f() == 2\n')"
  before="$(cksum < "$d/m.py")"
  vrun "$1" "$d/m.py" 1 'ENABLED = False' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran) — the mutated run ran no test' <<<"$out" \
    && grep -q '^  restore:    byte-identical$' <<<"$out" && [ "$(cksum < "$d/m.py")" = "$before" ]
}
arm_s8() {  # skip-gated: baseline skips all, the mutation un-skips a failing test -> 2 (was 0)
  local d
  d="$(skworld "s8-$2" 'ENABLED = False\ndef f():\n    return 2\n' 'import pytest\nimport m\n@pytest.mark.skipif(not m.ENABLED, reason="off")\ndef test_f():\n    assert m.f() == 3\n')"
  vrun "$1" "$d/m.py" 1 'ENABLED = True' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran) — the baseline is not GREEN' <<<"$out"
}
arm_s9() {  # -qq suppresses the summary: all-skipped -> 1 with the note on STDOUT (fail open)
  local d; d="$(skworld "s9-$2" "$M_F" "$T_SKIP")"
  out="$(bash "$1" "$d/m.py" 2 '    return 3' "${PYTEST_QQ[@]}" "$d/test_m.py" 2>/dev/null)"; rc=$?
  why="exit $rc"
  [ "$rc" -eq 1 ] && grep -q "$SKIP_NOTE_LINE" <<<"$out"
}
arm_s9b() { # the note prints on PROVEN too: -qq with a real kill -> 0 AND the note
  local d; d="$(pyworld "s9b-$2" "$M_F")"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST_QQ[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out" && grep -q "$SKIP_NOTE_LINE" <<<"$out"
}
arm_s10() { # strict xfail: baseline xfailed (rc 0), the mutation makes it XPASS(strict) -> 0
  local d; d="$(skworld "s10-$2" "$M_F" 'import pytest\nfrom m import f\n@pytest.mark.xfail(strict=True, reason="x")\ndef test_f():\n    assert f() == 3\n')"
  vrun "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" "$d/test_m.py"
  why="exit $rc"
  [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out"
}
arm_stub_note() {   # the stub pytest prints no summary: the check stands down and SAYS so
  arm_pytest_stub_kill "$1" && grep -q "$SKIP_NOTE_LINE" <<<"$out"
}
# A UTF-8 locale for s11. The fixture sets no locale, so under a C-locale hook env the seed
# and the mutant that drops LC_ALL=C would agree; the seed pins one itself.
U8=""
if command -v locale >/dev/null 2>&1; then
  _locs="$(locale -a 2>/dev/null)" || _locs=""
  if grep -qx 'en_US.UTF-8' <<<"$_locs"; then U8=en_US.UTF-8
  else U8="$(grep -iE '\.utf-?8$' <<<"$_locs" | head -n 1)" || U8=""; fi
fi
arm_s11() { # an all-skipped run whose log carries a non-UTF-8 byte (\xff under -s) -> 2
  local d; d="$(skworld "s11-$2" "$M_F" 'import sys, pytest\nfrom m import f\nsys.stdout.buffer.write(b"\\xff\\n"); sys.stdout.flush()\n@pytest.mark.skip(reason="x")\ndef test_f():\n    assert f() == 2\n')"
  out="$(LC_ALL="$U8" bash "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" -s "$d/test_m.py" 2>&1)"; rc=$?
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran)' <<<"$out"
}
# The `*)` arm: a parser that prints anything other than none/norun/ran must fail OPEN and
# say so. Probed on a copy whose parser prints NOTHING (the shape awk's abort produced).
arm_parser_dead() {
  arm_pytest_stub_kill "$1" && grep -q "$SKIP_NOTE_LINE" <<<"$out"
}

# rt_split <rendered words> -> each word a bash reader gets back, \037-terminated.
rt_split() { bash -c "set -- $1; printf '%s\037' \"\$@\"" 2>/dev/null; }
rt_join()  { printf '%s\037' "$@"; }
# rt_case <want-rc> <validator> <args...> -> sets $rt_why to the failed conjuncts (empty =
# round-trips). RT_TEST holds the test argv inside <args...>. The run must exit <want-rc>
# exactly, and the `$ ` line must equal the validator path as invoked plus every arg, flags
# and `--` included; stdout only, so stderr cannot be line one.
rt_case() {
  local want="$1" v="$2" o first tl rc; shift 2
  rt_why=""
  o="$(bash "$v" "$@" 2>/dev/null)"; rc=$?
  [ "$rc" -eq "$want" ] || rt_why="$rt_why rc=$rc"
  first=""; IFS= read -r first <<<"$o"
  case "$first" in
    '$ '*) [ "$(rt_split "${first#\$ }")" = "$(rt_join "$v" "$@")" ] || rt_why="$rt_why dollar-argv" ;;
    *)     rt_why="$rt_why no-dollar-line" ;;
  esac
  tl="$(sed -n 's/^  test://p' <<<"$o")"
  if [ -z "$tl" ]; then rt_why="$rt_why no-test-line"
  else [ "$(rt_split "$tl")" = "$(rt_join "${RT_TEST[@]}")" ] || rt_why="$rt_why test-argv"; fi
  rt_why="${rt_why# }"
  [ -z "$rt_why" ]
}
# rt_refusal <want-rc> <validator> <args...> -> sets $rt_why: a pre-restore refusal exits
# <want-rc> exactly (2 before any mutation, 3 for HARD) and prints NOTHING on stdout, so no
# `$ ` line. The two stdout tokens are exclusive, so a refusal that prints a `$ ` line is
# read on that conjunct alone.
rt_refusal() {
  local want="$1" v="$2" o rc; shift 2
  rt_why=""
  o="$(bash "$v" "$@" 2>/dev/null)"; rc=$?
  [ "$rc" -eq "$want" ] || rt_why="$rt_why rc=$rc"
  if grep -q '^\$ ' <<<"$o"; then rt_why="$rt_why dollar-on-refusal"
  elif [ -n "$o" ]; then rt_why="$rt_why stdout-not-empty"; fi
  rt_why="${rt_why# }"
  [ -z "$rt_why" ]
}
RT_QUOTE_REPL="x='it'\"'\"'s'"   # a replacement holding single and double quotes; kills disc.sh
# hardworld -> echoes a FRESH mktemp dir under $WORK holding Assertion 7's HARD world, seeded
# the way seed.sh seeds it: hard/sut.sh (a copy of the target), a run count at 0, and a test
# that removes hard/ on its SECOND run, so the restore has nowhere to write. The world destroys
# itself, so every drive needs its own. tmp/ is the validator's TMPDIR for the drive, so its
# backup, logs and mutant land inside this dir too and an aborted run leaves nothing outside it.
hardworld() {
  local d
  d="$(mktemp -d "$WORK/hw.XXXXXX")" || return 1
  mkdir -p "$d/hard" "$d/tmp" && cp "$SUT" "$d/hard/sut.sh" && printf '0\n' > "$d/count" || return 1
  cat > "$d/test.sh" <<HW || return 1
#!/usr/bin/env bash
n=\$(cat "$d/count")
n=\$((n + 1))
printf '%s\n' "\$n" > "$d/count"
[ "\$n" -ge 2 ] && rm -rf "$d/hard"
exit 0
HW
  printf '%s\n' "$d"
}
# arm_argv_roundtrip <validator>: case A (flags, `--`, a multi-word -k), case Q (a quoted
# replacement), the single-token control (`-k one`), case R (a RED baseline, refused before
# any mutation: exit 2 and an empty stdout), case H (HARD, the tree left mutated: exit 3 and
# an empty stdout), and case U (the coverage-only degenerate, UNPROVEN: exit 1, and line 1 is
# a `$ ` line that replays). The control is part of the arm: it must round-trip under a
# `test:` line joined with spaces too, which is what proves the test-argv conjunct
# discriminates only on a multi-word argument (mutant 15 reads it). U also runs the `test:`
# conjuncts; its test argv is single-token, so mutant 15 leaves it clean.
# R is the red-baseline world, not the no-op one, because its refusal sits later in the flow:
# a `$ ` printf moved anywhere above the baseline run prints on it (mutant 18 reads it). H is
# the LATEST pre-restore refusal, the restore verification itself, so a `$ ` printf placed
# anywhere above it prints on it, including after the baseline run (mutant 19 reads it).
# The tilde cases carry their words in the test argv, so both lines render them. bash 3.2's
# %q leaves `~` bare and the child bash in rt_split would expand it. T: a word-leading `~root`
# (root exists on every macOS and Linux box; a user that does not exist is not expanded and
# would discriminate nothing), `~+`, and the mid-word `a~root` that never expands. X: a `~`
# after `=` and after `:` (`x=~root`, `FOO=a:~/b`), which a leading-only escape misses
# (mutant 21). D: `~root<TAB>z`, which %q puts in $'...' form, where `\~` is NOT an escape,
# so an escape applied to every word breaks it (mutant 22). Mutant 20 reads T and X on the
# `test:` line alone.
# Case E: a replacement with multibyte characters, driven under a UTF-8 locale ($U8, resolved
# above). Under that locale bash 3.2's %q prints a multibyte lead byte raw and octal-escapes the
# continuation bytes, so an unscoped replay_words wrote a `$ ` and a `test:` line that are not
# valid UTF-8. The conjunct is that both lines carry 0 non-ASCII bytes. Benign-only: no
# --syntax-check, and a test argv that runs nothing but disc.sh.
rt_case_e() { # <validator> -> sets $rt_why
  local v="$1" o rc n
  rt_why=""
  o="$(LC_ALL="$U8" bash "$v" "$SUT" 2 "value() { printf '99\n'; }  # — é" bash "$WORK/disc.sh" 2>/dev/null)"; rc=$?
  [ "$rc" -eq 0 ] || rt_why="rc=$rc"
  n="$(grep -E '^(\$ |  test:)' <<<"$o" | LC_ALL=C grep -c '[^ -~]')" || n=0
  [ "$n" -eq 0 ] || rt_why="$rt_why non-ascii"
  rt_why="${rt_why# }"
  [ -z "$rt_why" ]
}

# The eleven cases of the capture round-trip, each an arm of its own so a mutant is driven on the
# one case that decides it. Each sets $why and returns 0 when its case holds.
arm_rt_A() { RT_TEST=(bash "$WORK/disc.sh" -k 'a or b' one)
  rt_case 0 "$1" --syntax-check 'bash -n' -- "$SUT" 2 "$MUTATED" "${RT_TEST[@]}"; why="A:[$rt_why]"; [ -z "$rt_why" ]; }
arm_rt_Q() { RT_TEST=(bash "$WORK/disc.sh")
  rt_case 0 "$1" "$SUT" 2 "$RT_QUOTE_REPL" "${RT_TEST[@]}"; why="Q:[$rt_why]"; [ -z "$rt_why" ]; }
arm_rt_control() { RT_TEST=(bash "$WORK/disc.sh" -k one)
  rt_case 0 "$1" "$SUT" 2 "$MUTATED" "${RT_TEST[@]}"; why="control:[$rt_why]"; [ -z "$rt_why" ]; }
arm_rt_R() {
  rt_refusal 2 "$1" "$SUT" 2 "$MUTATED" bash "$WORK/red.sh"; why="R:[$rt_why]"; [ -z "$rt_why" ]; }
arm_rt_H() { local hw h
  hw="$(hardworld)" || hw=""
  if [ -n "$hw" ] && [ -f "$hw/hard/sut.sh" ] && [ -f "$hw/test.sh" ]; then
    h="$(export TMPDIR="$hw/tmp"; rt_refusal 3 "$1" "$hw/hard/sut.sh" 2 "$MUTATED" bash "$hw/test.sh"; printf '%s' "$rt_why")"
  else h="no-hard-world"; fi
  why="H:[$h]"; [ -z "$h" ]; }
arm_rt_U() { RT_TEST=(bash "$WORK/nondisc.sh")
  rt_case 1 "$1" "$SUT" 2 "$MUTATED" "${RT_TEST[@]}"; why="U:[$rt_why]"; [ -z "$rt_why" ]; }
arm_rt_T() { RT_TEST=(bash "$WORK/disc.sh" '~root' 'a~root' '~+')
  rt_case 0 "$1" "$SUT" 2 "$MUTATED" "${RT_TEST[@]}"; why="T:[$rt_why]"; [ -z "$rt_why" ]; }
arm_rt_X() { RT_TEST=(bash "$WORK/disc.sh" 'x=~root' 'FOO=a:~/b')
  rt_case 0 "$1" "$SUT" 2 "$MUTATED" "${RT_TEST[@]}"; why="X:[$rt_why]"; [ -z "$rt_why" ]; }
arm_rt_D() { RT_TEST=(bash "$WORK/disc.sh" $'~root\tz')
  rt_case 0 "$1" "$SUT" 2 "$MUTATED" "${RT_TEST[@]}"; why="D:[$rt_why]"; [ -z "$rt_why" ]; }
arm_rt_E() { rt_case_e "$1"; why="E:[$rt_why]"; [ -z "$rt_why" ]; }
RT_ARMS="rt_A rt_Q rt_control rt_R rt_H rt_U rt_T rt_X rt_D rt_E"

# =============================================================================
# THE ARM REGISTRY. Every arm id is a function arm_<id>; a registered id with no function is a
# FIXTURE BROKEN before anything runs (a refused undefined helper, never a skipped arm).
# =============================================================================
ARMS="a1_unproven a2_noop a3_eof a4_red a5_special a7_hard a8_syntax a9_syntaxkill amp"
ARMS="$ARMS nonpytest_exit2 pytest_exit5 pytest_exit2 pytest_stub_kill later_pytest_word dash_m_pytest"
ARMS="$ARMS marker_refused marker_control ws_syntax_check stub_note parser_dead"
ARMS="$ARMS py_syntax py_return py_badbase py_marker pytest_collect pytest_green pytest_kill"
ARMS="$ARMS s1 s2 s3 s4 s5 s6 s7 s8 s9 s9b s10 s11 $RT_ARMS"
for _a in $ARMS; do
  declare -F "arm_$_a" >/dev/null 2>&1 || { echo "FIXTURE BROKEN: arm $_a is registered but arm_$_a is not defined" >&2; exit 2; }
done
HAVE_PY=0; command -v python3 >/dev/null 2>&1 && HAVE_PY=1
HAVE_PYTEST=0
[ "$HAVE_PY" -eq 1 ] && python3 -c 'import pytest' >/dev/null 2>&1 && HAVE_PYTEST=1
NEEDS_PY=" py_syntax py_return py_badbase py_marker "
NEEDS_PYTEST=" pytest_collect pytest_green pytest_kill s1 s2 s3 s4 s5 s6 s7 s8 s9 s9b s10 s11 "
NEEDS_U8=" s11 rt_E "
# arm_avail <arm> -> 0 when the tools it needs are present
arm_avail() {
  case "$NEEDS_PY" in *" $1 "*) [ "$HAVE_PY" -eq 1 ] || return 1 ;; esac
  case "$NEEDS_PYTEST" in *" $1 "*) [ "$HAVE_PYTEST" -eq 1 ] || return 1 ;; esac
  case "$NEEDS_U8" in *" $1 "*) [ -n "$U8" ] || return 1 ;; esac
  return 0
}
# armrun <arm> <validator> <world tag> -> the arm's own status, $why set
armrun() { "arm_$1" "$2" "$3"; }
BASE_OK=" "
# flagof <arm> -> 1 when the arm HELD against the shipped validator in THIS run, else 0
flagof() { case "$BASE_OK" in *" $1 "*) echo 1 ;; *) echo 0 ;; esac; }
# live <arm> <ok text> <failure text>: drive the arm on the shipped validator; a hold records its base flag.
live() {
  if armrun "$1" "$VALIDATOR" tip; then ok "$2"; BASE_OK="$BASE_OK$1 "
  else bad "$3 ($why)"; fi
}

echo "mutation-red-replay:"

# --- Assertion 0: SANITY — a genuine kill is PROVEN ---------------------------
# Every negative below would score a false pass against a script that is simply broken
# and refusing everything.
replay "$VALIDATOR" 2 "$MUTATED" "$WORK/disc.sh"
if [ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out"; then
  ok "a real mutation that kills the named test exits 0 (the negatives below mean something)"
else
  bad "FIXTURE BROKEN — a genuine mutation kill did not report PROVEN (exit $rc). Every assertion below would be a false pass."
  echo; echo "mutation-red-replay: $fails assertion(s) FAILED" >&2; exit 2
fi

# --- THE LIVE PASS: every arm against the SHIPPED validator, whole -----------------------
live a1_unproven "a test that runs the mutated line without asserting on its value exits 1 (UNPROVEN)" \
  "the coverage-only degenerate did not report UNPROVEN at exit 1 — the one verdict that is a finding about the test"
live a2_noop "a replacement identical to the line it replaces exits 2, not 1 (nothing was mutated, so nothing was disproved)" \
  "a no-op replacement did not exit 2 — an unmutated file was graded as a claim about a test"
live a3_eof "a line-number past the end of the file exits 2 (the rewrite had nothing to reach)" \
  "a line-number past EOF did not exit 2 — a file the script never touched was graded"
live a4_red "a named test that is RED before the mutation exits 2 (there is no GREEN -> RED transition to read)" \
  "a RED baseline did not exit 2 — a transition was reported off a run that never started GREEN"
live a5_special "replacements containing @, & and a backslash escape all mutate and kill (the replacement is data, not a rewrite program)" \
  "a replacement containing rewriter-special text did not mutate"
live amp "a replacement of '&' is a literal to the shipped rewrite (exit 0), the shipped half of mutant m3" \
  "a replacement of '&' did not exit 0 — the replacement is not being treated as data"
[ "$(cksum < "$SUT")" = "$BEFORE" ] \
  && ok "the target is byte-identical after the replays (PROVEN, UNPROVEN and the refusals)" \
  || bad "the target did not come back byte-identical — the replay left mutated source on disk"
live a7_hard "a restore that does not verify exits 3 and leaves the pre-mutation bytes on disk at the path it prints" \
  "a target that could not be restored did not exit 3 with an intact backup — a mutated tree was reported as a completed replay"

MUT="$WORK/mutants"
mkdir -p "$MUT"
# --- CONTROL: an unmutated copy in the same directory ------------------------
# A copy that cannot run at all fails every mutant assertion at once and scores as kills. This is
# what tells the two apart.
cp "$VALIDATOR" "$MUT/control.sh"
replay "$MUT/control.sh" 2 "$MUTATED" "$WORK/disc.sh"
[ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out" && ok "CONTROL: an unmutated copy still reports PROVEN (the mutants below fail for their own reasons)" \
  || bad "FIXTURE BROKEN — an unmutated copy of the validator does not work from \$MUT (exit $rc); every mutant below is a false kill"

live a8_syntax "--syntax-check 'bash -n' turns a non-parsing mutation (PROVEN without the flag) into exit 2, after a verified restore" \
  "--syntax-check 'bash -n' on a non-parsing mutation was not refused — a broken file was graded as a claim about the test"
live a9_syntaxkill "--syntax-check 'bash -n' with a mutation that parses and kills still exits 0 (PROVEN), with the -- terminator" \
  "--syntax-check refused a parsing kill — the check is not differential on the mutant"
live nonpytest_exit2 "a non-pytest runner whose real kill exits 2 exits 0 (PROVEN): the pytest-exit arm reads pytest only" \
  "a non-pytest runner exiting 2 on a real kill was not PROVEN — the pytest-exit arm is applied to every runner"
live pytest_exit5 "a stub named pytest exiting 5 exits 2 (pytest exit), after a verified restore" \
  "a pytest exit 5 was not refused — the pytest-exit arm refuses only some of 2-5"
live pytest_exit2 "the same stub exiting 2 exits 2 (pytest exit)" "a stub pytest exit 2 was not refused"
live pytest_stub_kill "the same stub exiting 1 exits 0 (PROVEN), so the stub is read as pytest and a test failure is a kill" \
  "a stub pytest exit 1 was not PROVEN"
live later_pytest_word "a make-style argv with pytest as a LATER word, real kill exiting 2, exits 0 (detection is anchored)" \
  "a later argv word 'pytest' was read as a pytest runner — a real kill was refused"
live dash_m_pytest "the same runner with a '-m pytest' pair exits 2 (the anchored detector still reads -m pytest)" \
  "a '-m pytest' argv was not read as pytest"
live marker_refused "a mutant refused by --syntax-check never runs the suite: the marker shows the baseline run only" \
  "a refused mutant ran the suite"
live marker_control "CONTROL: the marker counts the mutated run (a parsing kill leaves 2 runs)" \
  "FIXTURE BROKEN — the marked test did not record two runs on a parsing kill; the marker arm is vacuous"
live ws_syntax_check "--syntax-check of only whitespace exits 2 as usage, target untouched" \
  "--syntax-check ' ' did not refuse as usage — bash 3.2 expands an empty SC_ARGV under set -u"
live stub_note "a pytest with no summary line (the stub) is not refused: PROVEN, with the skip-check note (fail open)" \
  "the stub pytest with no summary line was refused or carried no skip-check note — the skip check fails closed"

if [ "$HAVE_PY" -eq 1 ]; then
  live py_syntax "a .py syntax-error mutation exits 2 (parse) and the target restores byte-identical" \
    "a .py syntax-error mutation was not refused by the parse arm — a SyntaxError was graded as a kill"
  live py_return "a module-level 'return 1' under a plain python runner exits 2 (compile() rejects what ast.parse accepts)" \
    "a module-level 'return 1' was not refused by the parse arm"
  live py_badbase "a baseline that does not compile leaves the parse arm off: a killing mutation still exits 0" \
    "a non-compiling baseline with a killing mutation did not exit 0 with 'parse: not checked (baseline does not compile)'"
  live py_marker "a mutant refused by the parse arm never runs the suite: the marker shows the baseline run only" \
    "a parse-refused mutant ran the suite"
else
  skip "python3 not found — the .py parse arms (syntax error, module-level return, non-compiling baseline, parse marker) did NOT run"
fi
if [ "$HAVE_PYTEST" -eq 1 ]; then
  live pytest_collect "a pytest collection error on a mutant that compiles exits 2 (pytest exit 2 is not a test failure)" \
    "a pytest collection error was graded as a kill"
  live pytest_green "a pytest run that stays GREEN under mutation still exits 1 (UNPROVEN outranks the pytest-exit arm)" \
    "a GREEN pytest mutated run did not exit 1"
  live pytest_kill "a pytest assertion failure (exit 1) under mutation still exits 0 (PROVEN)" \
    "a pytest assertion failure was not PROVEN — the pytest-exit arm refuses exit 1"
  live s1 "s1 -> 2/2: an all-skipped baseline exits 2 (no test ran) before mutating, target byte-identical" "s1: an all-skipped baseline was graded"
  live s2 "s2 -> 2/2: '1 skipped, 1 deselected' (-k keeps only the skipped test) exits 2" "s2: a skipped+deselected run was graded"
  live s3 "s3 -> 2/2: '1 skipped, 1 warning' exits 2 (a warning is not a test)" "s3: a skipped+warning run was graded"
  live s4 "s4 -> 2/2: PY_COLORS=1 all-skipped exits 2 (ANSI stripped before parsing)" "s4: a coloured all-skipped run was graded"
  live s5 "s5 -> 0/0: one skipped plus one passing test with a real kill exits 0 (a test ran)" "s5: a mixed skip+pass run was not PROVEN"
  live s6 "s6 -> 0/0: a -s test printing a fake '1 skipped' line is read by the LAST summary line and exits 0" "s6: a printed fake summary line decided the verdict"
  live s7 "s7 -> 2/2: a mutation flipping a skipif to skip-all exits 2 after a verified restore" "s7: an all-skipped MUTATED run was graded"
  live s8 "s8 -> 2/2: a skip-gated test (skipped at baseline, un-skipped and failing under mutation) exits 2" "s8: a skip-gated test was PROVEN off a baseline that ran nothing"
  live s9 "s9 -> 1/1: -qq all-skipped is not refused (no summary line): exit 1 with the skip-check note on stdout" "s9: -qq all-skipped did not fail open with the note"
  live s9b "s9b -> 0/0: -qq with a real kill is PROVEN and still prints the skip-check note" "s9b: the skip-check note is not printed on PROVEN"
  live s10 "s10 -> 0/0: a strict xfail turned XPASS by the mutation exits 0 (xfailed counts as ran)" "s10: a strict-xfail kill was not PROVEN"
  if [ -n "$U8" ]; then
    live s11 "s11 -> 2/2: an all-skipped run whose log carries \\xff exits 2 under LC_ALL=$U8 (the parser reads bytes)" \
      "s11: a non-UTF-8 byte in the log defeated the skip check under LC_ALL=$U8"
  else
    skip "no UTF-8 locale in 'locale -a' — s11 (non-UTF-8 byte in the log) did NOT run"
  fi
else
  skip "pytest not importable by python3 — the pytest-exit arms and the skip-check seeds s1-s11 did NOT run"
fi
[ -n "$U8" ] || skip "no UTF-8 locale — case E of the capture round-trip and mutant m23 did NOT run"

# arm_argv_roundtrip <validator> <live>: the ten capture cases (flags, --, a multi-word -k, a
# quoted replacement, the single-token control, a RED refusal exiting 2, a HARD refusal exiting 3,
# an UNPROVEN exit 1, the tilde words, a multibyte replacement), each an arm of its own. The
# single-token control is part of it: it must round-trip too, which is what proves the test-argv
# conjunct discriminates only on a multi-word argument.
arm_argv_roundtrip() {
  local r all="" bad_n=0
  for r in $RT_ARMS; do
    arm_avail "$r" || continue
    if armrun "$r" "$1" tip; then [ "$2" != live ] || BASE_OK="$BASE_OK$r "
    else bad_n=1; all="$all $why"; fi
  done
  why="$all"
  [ "$bad_n" -eq 0 ]
}
arm_argv_roundtrip "$VALIDATOR" live \
  && ok "arm_argv_roundtrip: the \`\$ \` line and the \`test:\` line replay, through bash, to the exact argv (flags, --, a multi-word -k, a quoted replacement, the single-token control, an UNPROVEN exit 1, the tilde words and a multibyte replacement), a RED-baseline refusal exits 2 and a HARD refusal exits 3, each with no \`\$ \` line" \
  || bad "arm_argv_roundtrip: the capture does not replay to its own argv, or a refusal printed one ($why) — a committed capture is a command that does not run"
arm_argv_roundtrip "$MUT/control.sh" copy \
  && ok "CONTROL: arm_argv_roundtrip holds on an unmutated copy in \$MUT, \`\$ \` naming the copy's path as invoked" \
  || bad "FIXTURE BROKEN — arm_argv_roundtrip fails on an unmutated copy ($why); the capture mutants below would be false kills"

# =============================================================================
# MUTANTS. Each is a COPY, guarded so a substitution that matched nothing cannot pass as a
# mutation. Built here, scored below. mkmut refuses a producer that failed, an empty copy and a
# copy identical to the validator; it is called in THIS shell so its `bad` reaches $fails.
# =============================================================================
mkmut() {
  if [ "$2" -ne 0 ] || [ ! -s "$MUT/$1.sh" ] || cmp -s "$VALIDATOR" "$MUT/$1.sh"; then
    bad "FIXTURE BROKEN: mutant $1 DID NOT APPLY (producer exit $2), so its assertion is unproven"
    return 1
  fi
}
# insert_after <anchor> <line> [<source>]: print <line> after the one line starting with
# <anchor> in <source> (default the validator); exits 1 unless the anchor matched exactly once.
insert_after() {
  A="$1" L="$2" awk 'BEGIN { n = 0 } { print } index($0, ENVIRON["A"]) == 1 { print ENVIRON["L"]; n++ } END { if (n != 1) exit 1 }' "${3:-$VALIDATOR}"
}
replace_line() {
  A="$1" L="$2" awk 'BEGIN { n = 0 } $0 == ENVIRON["A"] { n++; if (ENVIRON["L"] != "") print ENVIRON["L"]; next } { print } END { if (n != 1) exit 1 }' "${3:-$VALIDATOR}"
}
RT_DOLLAR_LINE="printf '\$'; replay_words \"\$0\" \${ORIG_ARGV[@]+\"\${ORIG_ARGV[@]}\"}; printf '\\n'"
RT_TEST_LINE="printf '  test:      '; replay_words \"\${TEST_CMD[@]}\"; printf '\\n'"
RT_TILDE_LINE="          [ \"\$c\" = '~' ] && c='\\~'"
RT_DQ_LINE="      \"\\\$'\"*) ;;"

BUILT=" "
mk() { if mkmut "$1" "$2"; then BUILT="$BUILT$1 "; fi; }
# m1: both no-op guards removed. REVERT EVERY LAYER: strip either guard alone and the other still exits 2.
sed -e 's@^if \[ "\$CURRENT" = "\$REPL" \]; then@if false; then@' \
    -e 's@^if cmp -s "\$BACKUP" "\$TARGET"; then@if false; then@' \
    "$VALIDATOR" > "$MUT/m1.sh"; prc=$?
n="$(grep -c '^if false; then' "$MUT/m1.sh")" || n=0
[ "$n" -eq 2 ] || prc=9
mk m1 "$prc"
# m2: the restore verification removed.
sed 's@^if ! cmp -s "\$BACKUP" "\$TARGET"; then@if false; then@' "$VALIDATOR" > "$MUT/m2.sh"; prc=$?
mk m2 "$prc"
# m3: the rewrite done by sed, as the absorbed script did it. `&` is one character of source to the
# shipped rewrite and the whole matched line to sed's. The delimiter here is `|`, because the line
# being written IS a sed program full of `@`.
sed 's|^REPL="\$REPL" awk .*> "\$MUTANT"$|sed "${LINE}s@.*@${REPL}@" "$BACKUP" > "$MUTANT"|' "$VALIDATOR" > "$MUT/m3.sh"; prc=$?
mk m3 "$prc"
# m4: syntax-check refusal exits 2 BEFORE the restore. The EXIT trap still restores the file, so rc
# and the bytes on disk are both right; only the printed verified restore is missing.
insert_after '  REFUSED="syntax-check"' '  exit 2' > "$MUT/m4.sh"; prc=$?
mk m4 "$prc"
# m5: ast.parse instead of compile().
sed 's@compile(open(sys.argv\[1\], "rb").read(), sys.argv\[1\], "exec")@__import__("ast").parse(open(sys.argv[1], "rb").read(), sys.argv[1])@' \
  "$VALIDATOR" > "$MUT/m5.sh"; prc=$?
mk m5 "$prc"
# m6: non-differential — the baseline gate removed, the arm always on for *.py.
sed 's@^    elif py_compiles "\$TARGET" baseline; then$@    elif true; then@' "$VALIDATOR" > "$MUT/m6.sh"; prc=$?
mk m6 "$prc"
# m7: the mutant check reads the BACKUP, which always compiles when the baseline did.
sed 's@! py_compiles "\$TARGET" mutant; then@! py_compiles "$BACKUP" mutant; then@' "$VALIDATOR" > "$MUT/m7.sh"; prc=$?
mk m7 "$prc"
# m8: parse refusal exits 2 BEFORE the restore. The EXIT trap still puts the bytes back and the exit
# is still 2, so the printed verified restore is the only thing that separates it.
insert_after '  REFUSED="parse"' '  exit 2' > "$MUT/m8.sh"; prc=$?
mk m8 "$prc"
# m9: the pytest arm takes precedence over exit 0, so a GREEN pytest run reads UNEVALUABLE.
sed 's@^if \[ "\$mut_rc" -eq 0 \]; then$@if [ "$mut_rc" -eq 0 ] \&\& [ "$IS_PYTEST" -eq 0 ]; then@' "$VALIDATOR" > "$MUT/m9.sh"; prc=$?
mk m9 "$prc"
# m10: the pytest-exit arm applied to every runner.
sed 's@^if \[ "\$IS_PYTEST" -eq 1 \] && \[ "\$mut_rc" -ne 1 \]; then$@if [ "$mut_rc" -ne 1 ]; then@' "$VALIDATOR" > "$MUT/m10.sh"; prc=$?
mk m10 "$prc"
# m11: only pytest exit 2 refused.
sed 's@^if \[ "\$IS_PYTEST" -eq 1 \] && \[ "\$mut_rc" -ne 1 \]; then$@if [ "$IS_PYTEST" -eq 1 ] \&\& [ "$mut_rc" -eq 2 ]; then@' "$VALIDATOR" > "$MUT/m11.sh"; prc=$?
mk m11 "$prc"
# m12: the suite still runs on a refused mutant (the verdict is unchanged).
sed 's@^if \[ -z "\$REFUSED" \]; then$@if true; then@' "$VALIDATOR" > "$MUT/m12.sh"; prc=$?
mk m12 "$prc"
# m13: unanchored detection, here keyed on the LAST word instead of the first.
sed 's|^case "\${TEST_CMD\[0\]##\*/}" in$|case "${TEST_CMD[${#TEST_CMD[@]}-1]##*/}" in|' "$VALIDATOR" > "$MUT/m13.sh"; prc=$?
mk m13 "$prc"
# m14: the whitespace-only --syntax-check guard removed.
sed 's|^  if \[ "\${#SC_ARGV\[@\]}" -eq 0 \]; then$|  if false; then|' "$VALIDATOR" > "$MUT/m14.sh"; prc=$?
mk m14 "$prc"
# m15: the `test:` line joined with spaces, as before the fix.
replace_line "$RT_TEST_LINE" "printf '  test:       %s\\n' \"\${TEST_CMD[*]}\"" > "$MUT/m15.sh"; prc=$?
mk m15 "$prc"
# m16: no `$ ` line at all.
replace_line "$RT_DOLLAR_LINE" "" > "$MUT/m16.sh"; prc=$?
mk m16 "$prc"
# m17: the `$ ` line rebuilt from the parsed values, through the same replay_words.
replace_line "$RT_DOLLAR_LINE" "printf '\$'; replay_words \"\$0\" \"\$TARGET\" \"\$LINE\" \"\$REPL\" \"\${TEST_CMD[@]}\"; printf '\\n'" > "$MUT/m17.sh"; prc=$?
mk m17 "$prc"
# m18: the `$ ` printf hoisted to just after `ORIG_ARGV=("$@")`. Delete first, then insert into the
# copy: inserting first would leave two lines for replace_line to match.
replace_line "$RT_DOLLAR_LINE" "" > "$MUT/m18-del.sh"; prc=$?
[ "$prc" -ne 0 ] || { insert_after 'ORIG_ARGV=("$@")' "$RT_DOLLAR_LINE" "$MUT/m18-del.sh" > "$MUT/m18.sh"; prc=$?; }
mk m18 "$prc"
# m19: the `$ ` printf moved to just after the restore's `cp`, before the verification that exits 3.
replace_line "$RT_DOLLAR_LINE" "" > "$MUT/m19-del.sh"; prc=$?
[ "$prc" -ne 0 ] || { insert_after 'cp "$BACKUP" "$TARGET" 2>/dev/null' "$RT_DOLLAR_LINE" "$MUT/m19-del.sh" > "$MUT/m19.sh"; prc=$?; }
mk m19 "$prc"
# m20: the tilde escape applied to the `$ ` line only; the `test:` line back to bare %q.
replace_line "$RT_TEST_LINE" "printf '  test:      '; printf ' %q' \"\${TEST_CMD[@]}\"; printf '\\n'" > "$MUT/m20.sh"; prc=$?
mk m20 "$prc"
# m21: only a word-LEADING `~` escaped.
replace_line "$RT_TILDE_LINE" "          [ \"\$c\" = '~' ] && [ \"\$i\" -eq 0 ] && c='\\~'" > "$MUT/m21.sh"; prc=$?
mk m21 "$prc"
# m22: the escape applied to a $'...' word too.
replace_line "$RT_DQ_LINE" "      \"\\\$'\"*) q=\"\${q//\\~/\\\\~}\" ;;" > "$MUT/m22.sh"; prc=$?
mk m22 "$prc"
# m23: replay_words without its scoped LC_ALL=C, as before the fix.
replace_line "  local w q out c i LC_ALL=C" "  local w q out c i" > "$MUT/m23.sh"; prc=$?
mk m23 "$prc"
# sk1: both skip checks removed (every layer: the baseline and the mutated read).
sed -e 's@^  case "\$(pytest_summary "\$BASE_LOG")" in$@  case "ran" in@' \
    -e 's@^  case "\$(pytest_summary "\$MUT_LOG")" in$@  case "ran" in@' "$VALIDATOR" > "$MUT/sk1.sh"; prc=$?
n="$(grep -c '^  case "ran" in$' "$MUT/sk1.sh")" || n=0
[ "$n" -eq 2 ] || prc=9
mk sk1 "$prc"
# sk2: refuse whenever any skipped/deselected word is present (ignores the words that ran).
sed 's@^      print ((ran == 0 \&\& idle == 1) ? "norun" : "ran")$@      print (idle == 1 ? "norun" : "ran")@' "$VALIDATOR" > "$MUT/sk2.sh"; prc=$?
mk sk2 "$prc"
# sk3: the check applied to the baseline only.
sed 's@^if \[ -z "\$REFUSED" \] && \[ "\$IS_PYTEST" -eq 1 \]; then$@if false; then@' "$VALIDATOR" > "$MUT/sk3.sh"; prc=$?
mk sk3 "$prc"
# sk4: fail CLOSED on a missing summary line at baseline.
sed 's@^    \*) SKIP_NOTE="\$SKIP_NOTE_TEXT" ;;$@    *) echo "validate-mutation-red: UNEVALUABLE (no test ran) — no pytest summary line" >\&2; exit 2 ;;@' "$VALIDATOR" > "$MUT/sk4.sh"; prc=$?
mk sk4 "$prc"
# sk5: FIRST matching summary line instead of the last.
sed 's@^        last = line$@        if (last == "") last = line@' "$VALIDATOR" > "$MUT/sk5.sh"; prc=$?
mk sk5 "$prc"
# sk6: no ANSI strip.
sed 's@^      gsub(esc "\\\\\[\[0-9;\]\*m", "", line)$@      line = line@' "$VALIDATOR" > "$MUT/sk6.sh"; prc=$?
mk sk6 "$prc"
# sk7: refuse only a bare `N skipped` line.
sed 's@^      print ((ran == 0 \&\& idle == 1) ? "norun" : "ran")$@      print ((n == 1 \&\& last ~ /^[0-9]+ skipped$/) ? "norun" : "ran")@' "$VALIDATOR" > "$MUT/sk7.sh"; prc=$?
mk sk7 "$prc"
# sk8: the parse runs in the caller's locale (LC_ALL=C dropped).
sed 's@^  LC_ALL=C awk '"'"'$@  awk '"'"'@' "$VALIDATOR" > "$MUT/sk8.sh"; prc=$?
mk sk8 "$prc"
# The `*)` probe: a copy whose parser prints NOTHING (awk replaced by `true`). sk9 is that copy with
# both `*)` arms narrowed to `none)`, so an empty parse neither refuses nor notes.
sed 's@^  LC_ALL=C awk '"'"'$@  LC_ALL=C true '"'"'@' "$VALIDATOR" > "$MUT/pdead.sh"; prc=$?
mkmut pdead "$prc" || true
sed -e 's@^    \*) SKIP_NOTE="\$SKIP_NOTE_TEXT" ;;$@    none) SKIP_NOTE="$SKIP_NOTE_TEXT" ;;@' \
    -e 's@^    \*)     SKIP_NOTE="\$SKIP_NOTE_TEXT" ;;$@    none)  SKIP_NOTE="$SKIP_NOTE_TEXT" ;;@' \
    "$MUT/pdead.sh" > "$MUT/sk9.sh"; prc=$?
n1="$(grep -c 'SKIP_NOTE="\$SKIP_NOTE_TEXT" ;;$' "$MUT/sk9.sh")" || n1=0
n2="$(grep -c '^    \*) *SKIP_NOTE=' "$MUT/sk9.sh")" || n2=0
{ [ "$n1" -eq 2 ] && [ "$n2" -eq 0 ] && ! cmp -s "$MUT/pdead.sh" "$MUT/sk9.sh"; } || prc=9
mk sk9 "$prc"
# The parser-dead probe: the unmutated-shape copy must fail OPEN through the `*)` arm.
if [ -s "$MUT/pdead.sh" ] && arm_avail parser_dead; then
  live_pd() { if armrun parser_dead "$MUT/pdead.sh" pd; then ok "a parser that prints nothing fails OPEN through the \`*)\` arm: PROVEN with the skip-check note"; BASE_OK="$BASE_OK""parser_dead "
              else bad "a parser that prints nothing did not fail open with the note ($why) — the \`*)\` arm is missing"; fi; }
  live_pd
fi

MUTS="m1 m2 m3 m4 m5 m6 m7 m8 m9 m10 m11 m12 m13 m14 m15 m16 m17 m18 m19 m20 m21 m22 m23 sk1 sk2 sk3 sk4 sk5 sk6 sk7 sk8 sk9"

# score_mutant <name>: the deciding arm(s) of the header row must FAIL on the copy, each twin must
# HOLD on it, and the kill is emitted through mutant_killed behind the base flags of every arm it
# drove (decides and twins) against the SHIPPED validator in THIS run.
score_mutant() {
  local m="$1" row dec twn a flag=0 nb="" kwhy=""
  case "$BUILT" in *" $m "*) ;; *) return 0 ;; esac
  row="$(awk -v m="$m" '$1 == "#" && $2 == "MUTANT-MATRIX" && $3 == m { print; exit }' "$HERE/run.sh")"
  if [ -z "$row" ]; then bad "FIXTURE BROKEN: mutant $m carries no # MUTANT-MATRIX row in the header, so it has no deciding arm"; return 0; fi
  dec="$(sed -n 's/.* decides=\([^ ]*\).*/\1/p' <<<"$row")"; dec="${dec//,/ }"
  twn="$(sed -n 's/.* twins=\([^ ]*\).*/\1/p' <<<"$row")"; twn="${twn//,/ }"
  if [ -z "$dec" ] || [ -z "$twn" ] || [ "$twn" = "-" ]; then bad "FIXTURE BROKEN: mutant $m header row has no decides= or twins= arm"; return 0; fi
  for a in $dec $twn; do
    declare -F "arm_$a" >/dev/null 2>&1 || { bad "FIXTURE BROKEN: mutant $m names arm $a, which is not defined"; return 0; }
    arm_avail "$a" || { skip "mutant $m needs the tools of arm $a, which are absent — it did NOT run"; return 0; }
    [ "$(flagof "$a")" = 1 ] || nb="$nb $a"
  done
  if [ -z "$nb" ]; then flag=1; else bad "MUTANT $m: arm(s)$nb did not pass unmutated in this run, so its kill cannot score"; fi
  for a in $dec; do
    if armrun "$a" "$MUT/$m.sh" "$m"; then bad "MUTANT $m survived its deciding arm $a"; return 0; fi
    kwhy="$kwhy $a:$why"
  done
  for a in $twn; do
    if ! armrun "$a" "$MUT/$m.sh" "$m"; then bad "MUTANT $m also failed its twin $a ($why) — the deciding arm is entangled"; return 0; fi
  done
  mutant_killed "$flag" "$m" "MUTANT $m is killed by$kwhy; twin(s) $twn still hold"
}

# matrix_all: every built mutant against every arm. FAIL = the arm fails on the copy.
matrix_cell() { MATRIX_CELLS=$((MATRIX_CELLS+1)); printf 'MATRIX\t%s\t%s\t%s\n' "$1" "$2" "$3"; }
matrix_all() {
  local m a r
  for a in $ARMS; do
    arm_avail "$a" || { echo "FIXTURE BROKEN: --matrix needs the tools of arm $a" >&2; exit 2; }
  done
  for m in $MUTS; do
    case "$BUILT" in *" $m "*) ;; *) continue ;; esac
    for a in $ARMS; do
      if armrun "$a" "$MUT/$m.sh" "$m"; then r=ok; else r=FAIL; fi
      cp "$WORK/sut.orig" "$SUT"
      matrix_cell "$m" "$a" "$r"
    done
  done
}

if [ "$MATRIX" -eq 1 ]; then
  matrix_all
else
  for m in $MUTS; do score_mutant "$m"; done
fi

# A PLAIN RUN EXECUTES NO MATRIX-ONLY CELL. The counter is bumped by the one function that prints a
# MATRIX cell; under --matrix it must be non-zero, which proves the counter can fire.
if [ "$MATRIX" -eq 1 ]; then
  if [ "$MATRIX_CELLS" -gt 0 ]; then ok "--matrix executed $MATRIX_CELLS matrix cell(s) (the counter fires)"; else bad "--matrix executed no matrix cell: the counter cannot fire"; fi
else
  if [ "$MATRIX_CELLS" -eq 0 ]; then ok "a plain run executes no matrix-only cell"; else bad "a plain run executed $MATRIX_CELLS matrix-only cell(s)"; fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "mutation-red-replay: PASS"; exit 0; fi
echo "mutation-red-replay: $fails assertion(s) FAILED" >&2
exit 1
