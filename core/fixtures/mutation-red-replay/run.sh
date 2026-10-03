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
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

MUTATED="value() { printf '99\n'; }"   # a real change to line 2's value
SUT="$WORK/sut.sh"
BEFORE="$(cksum < "$SUT")"

# replay <validator> <line> <replacement> <test> -> sets $rc and $out
replay() {
  local v="$1" line="$2" repl="$3" test="$4"
  out="$(bash "$v" "$SUT" "$line" "$repl" bash "$test" 2>&1)"
  rc=$?
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

# --- Assertion 1: the coverage-only degenerate is UNPROVEN, exit 1 ------------
# The test executes the mutated line and never asserts on its value. This is the one
# outcome that IS a finding about the test.
replay "$VALIDATOR" 2 "$MUTATED" "$WORK/nondisc.sh"
[ "$rc" -eq 1 ] && grep -q 'stayed GREEN under a real mutation' <<<"$out" \
  && ok "a test that runs the mutated line without asserting on its value exits 1 (UNPROVEN)" \
  || bad "the coverage-only degenerate did not report UNPROVEN at exit 1 (exit $rc) — the one verdict that is a finding about the test"

# --- Assertion 2: a no-op replacement is UNEVALUABLE, exit 2 — NOT 1 ---------
# The absorbed defect. The line and the replacement are the same bytes, so the run below
# grades an unmutated file, and its GREEN says nothing about the claim.
replay "$VALIDATOR" 2 "value() { printf '42\n'; }" "$WORK/disc.sh"
[ "$rc" -eq 2 ] && ok "a replacement identical to the line it replaces exits 2, not 1 (nothing was mutated, so nothing was disproved)" \
  || bad "a no-op replacement exited $rc — an unmutated file was graded as a claim about a test"

# --- Assertion 3: a line past the end of the file is UNEVALUABLE, exit 2 -----
replay "$VALIDATOR" 99 "$MUTATED" "$WORK/disc.sh"
[ "$rc" -eq 2 ] && grep -q 'cannot be mutated' <<<"$out" \
  && ok "a line-number past the end of the file exits 2 (the rewrite had nothing to reach)" \
  || bad "a line-number past EOF exited $rc — a file the script never touched was graded"

# --- Assertion 4: a baseline that is already RED is UNEVALUABLE, exit 2 ------
replay "$VALIDATOR" 2 "$MUTATED" "$WORK/red.sh"
[ "$rc" -eq 2 ] && grep -q 'not GREEN before the mutation' <<<"$out" \
  && ok "a named test that is RED before the mutation exits 2 (there is no GREEN -> RED transition to read)" \
  || bad "a RED baseline exited $rc — a transition was reported off a run that never started GREEN"

# --- Assertion 5: replacement text that is live to a rewriter still lands ----
# `@` is the delimiter the absorbed implementation used and `&` is its back-reference;
# both are ordinary characters in a line of source. Each must produce a REAL mutation.
special_bad=0
for special in 'value() { printf "9@9\n"; }' 'value() { printf "9&9\n"; }' 'value() { printf "9\\19\n"; }'; do
  replay "$VALIDATOR" 2 "$special" "$WORK/disc.sh"
  [ "$rc" -eq 0 ] || { bad "a replacement containing rewriter-special text did not mutate (exit $rc): $special"; special_bad=1; }
done
[ "$special_bad" -eq 0 ] \
  && ok "replacements containing @, & and a backslash escape all mutate and kill (the replacement is data, not a rewrite program)"

# --- Assertion 6: the file comes back byte-identical from every path above ---
[ "$(cksum < "$SUT")" = "$BEFORE" ] \
  && ok "the target is byte-identical after six replays (PROVEN, UNPROVEN and four refusals)" \
  || bad "the target did not come back byte-identical — the replay left mutated source on disk"

# --- Assertion 7: a restore that does not verify is HARD, exit 3 -------------
# The named test destroys the target's directory on its second run, so the restore has
# nowhere to write. The verdict the run was heading for (the test exits 0, so UNPROVEN)
# must NOT be printed: a tree that is still mutated outranks a claim about a test.
out="$(bash "$VALIDATOR" "$WORK/hard/sut.sh" 2 "$MUTATED" bash "$WORK/hard-test.sh" 2>&1)"
rc=$?
if [ "$rc" -eq 3 ]; then
  bkp="$(printf '%s\n' "$out" | sed -n 's@.*pre-mutation bytes are at: @@p')"
  if [ -n "$bkp" ] && [ -f "$bkp" ] && [ "$(cksum < "$bkp")" = "$BEFORE" ]; then
    ok "a restore that does not verify exits 3 and leaves the pre-mutation bytes on disk at the path it prints"
  else
    bad "exit 3 was reported but the backup path it printed does not hold the pre-mutation bytes — the operator has no way back"
  fi
else
  bad "a target that could not be restored exited $rc — a mutated tree was reported as a completed replay"
fi

# =============================================================================
# MUTANTS. Each is a COPY, guarded by cmp -s so a substitution that matched nothing
# cannot pass as a mutation, and each asserts a POSITIVE outcome of its own.
# =============================================================================
MUT="$WORK/mutants"
mkdir -p "$MUT"

# --- CONTROL: an unmutated copy in the same directory ------------------------
# A copy that cannot run at all fails every mutant assertion at once and scores as three
# kills. This is what tells the two apart.
cp "$VALIDATOR" "$MUT/control.sh"
replay "$MUT/control.sh" 2 "$MUTATED" "$WORK/disc.sh"
[ "$rc" -eq 0 ] && ok "CONTROL: an unmutated copy still reports PROVEN (the mutants below fail for their own reasons)" \
  || bad "FIXTURE BROKEN — an unmutated copy of the validator does not work from \$MUT (exit $rc); every mutant below is a false kill"

# --- MUTANT 1: both no-op guards removed -------------------------------------
# REVERT EVERY LAYER. The identity check and the cmp check are two guards over one
# defect: strip either alone and the other still exits 2, and the mutant comes out green
# proving the layer left in place.
sed -e 's@^if \[ "\$CURRENT" = "\$REPL" \]; then@if false; then@' \
    -e 's@^if cmp -s "\$BACKUP" "\$TARGET"; then@if false; then@' \
    "$VALIDATOR" > "$MUT/m1.sh"
n="$(grep -c '^if false; then' "$MUT/m1.sh")"
if cmp -s "$VALIDATOR" "$MUT/m1.sh" || [ "$n" -ne 2 ]; then
  bad "FIXTURE BROKEN: mutant 1 disabled $n of 2 no-op guards, so this assertion is unproven"
else
  replay "$MUT/m1.sh" 2 "value() { printf '42\n'; }" "$WORK/disc.sh"
  [ "$rc" -eq 1 ] && ok "MUTANT 1: with both no-op guards gone, a replacement identical to its own line reports UNPROVEN — the absorbed defect, reproduced" \
    || bad "MUTANT 1 exited $rc: the no-op guards are not what keeps an unmutated file out of the UNPROVEN arm"
fi

# --- MUTANT 2: the restore verification removed ------------------------------
sed 's@^if ! cmp -s "\$BACKUP" "\$TARGET"; then@if false; then@' "$VALIDATOR" > "$MUT/m2.sh"
if cmp -s "$VALIDATOR" "$MUT/m2.sh"; then
  bad "FIXTURE BROKEN: mutant 2 matched nothing, so this assertion is unproven"
else
  rm -rf "$WORK/hard"; mkdir -p "$WORK/hard"; cp "$SUT" "$WORK/hard/sut.sh"; printf '0\n' > "$WORK/hard-count"
  out="$(bash "$MUT/m2.sh" "$WORK/hard/sut.sh" 2 "$MUTATED" bash "$WORK/hard-test.sh" 2>&1)"
  rc=$?
  [ "$rc" -eq 1 ] && ok "MUTANT 2: with the restore verification gone, a tree left mutated reports a verdict about the test instead (exit 1)" \
    || bad "MUTANT 2 exited $rc: the restore verification is not what turns an unrestored tree into a refusal"
fi

# --- MUTANT 3: the rewrite done by sed, as the absorbed script did it --------
# `&` is one character of source to the shipped rewrite and the whole matched line to
# sed's. Under sed the line is silently replaced by itself, so the replay grades a file
# it believes it mutated — caught here only because the cmp guard survives this mutant.
# The delimiter here is `|`, because the line being written IS a sed program full of `@`.
sed 's|^REPL="\$REPL" awk .*> "\$MUTANT"$|sed "${LINE}s@.*@${REPL}@" "$BACKUP" > "$MUTANT"|' "$VALIDATOR" > "$MUT/m3.sh"
if cmp -s "$VALIDATOR" "$MUT/m3.sh"; then
  bad "FIXTURE BROKEN: mutant 3 matched nothing, so this assertion is unproven"
else
  replay "$MUT/m3.sh" 2 '&' "$WORK/disc.sh"
  m3rc="$rc"
  replay "$VALIDATOR" 2 '&' "$WORK/disc.sh"
  if [ "$rc" -eq 0 ] && [ "$m3rc" -eq 2 ]; then
    ok "MUTANT 3: a replacement of '&' is a literal to the shipped rewrite (exit 0) and a back-reference to sed's, which rewrites the line to itself (exit 2)"
  else
    bad "MUTANT 3: shipped exited $rc and the sed rewrite exited $m3rc — the replacement is not being treated as data"
  fi
fi

# =============================================================================
# THE MUTATION THAT BREAKS THE FILE INSTEAD OF THE TEST. A replacement that does not parse
# makes the runner exit non-zero before any test body runs, and a bare `mut_rc != 0` grades
# that as PROVEN. Every refusal arm below is PRESENCE-shaped: it requires the arm's own
# `UNEVALUABLE (<arm>)` message, because a validator that refuses the flag as an unknown
# target also exits 2 and must not score as one that ran the check.
# =============================================================================

# vrun <validator> <args...> -> sets $rc and $out (stdout and stderr together)
vrun() {
  local v="$1"; shift
  out="$(bash "$v" "$@" 2>&1)"
  rc=$?
}
SH_BROKEN='value() {'                       # does not parse: bash -n fails, the run fails
SH_KILL="value() { printf '9\n'; }"         # parses, and kills disc.sh

# --- Assertion 8: --syntax-check refuses a non-parsing mutant, no python needed --------
# Without the flag the same mutation is PROVEN (the run dies on a parse error, which is
# RED): that is the residue the header states, and the control that the flag is the cause.
vrun "$VALIDATOR" "$SUT" 2 "$SH_BROKEN" bash "$WORK/disc.sh"
sh_noflag_rc="$rc"
vrun "$VALIDATOR" --syntax-check 'bash -n' "$SUT" 2 "$SH_BROKEN" bash "$WORK/disc.sh"
if [ "$sh_noflag_rc" -eq 0 ] && [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (syntax-check)' <<<"$out" \
   && grep -q '^  restore:    byte-identical$' <<<"$out"; then
  ok "--syntax-check 'bash -n' turns a non-parsing mutation (PROVEN without the flag) into exit 2, after a verified restore"
else
  bad "--syntax-check 'bash -n' on a non-parsing mutation exited $rc (without the flag: $sh_noflag_rc) — a broken file was graded as a claim about the test"
fi

# --- Assertion 9: the same flag leaves a parsing kill PROVEN ----------------------------
vrun "$VALIDATOR" --syntax-check 'bash -n' -- "$SUT" 2 "$SH_KILL" bash "$WORK/disc.sh"
[ "$rc" -eq 0 ] && grep -q '^PROVEN:' <<<"$out" \
  && ok "--syntax-check 'bash -n' with a mutation that parses and kills still exits 0 (PROVEN), with the -- terminator" \
  || bad "--syntax-check refused a parsing kill (exit $rc) — the check is not differential on the mutant"

# --- Arms 10-14 need no python: each is a shell runner or a stub named pytest. Each is a
# function of the validator so the mutants further down drive the same arm. Each returns 0
# when it holds, else sets $why and returns 1.
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

arm_nonpytest_exit2 "$VALIDATOR" \
  && ok "a non-pytest runner whose real kill exits 2 exits 0 (PROVEN): the pytest-exit arm reads pytest only" \
  || bad "a non-pytest runner exiting 2 on a real kill was not PROVEN ($why) — the pytest-exit arm is applied to every runner"
arm_pytest_exit5 "$VALIDATOR" \
  && ok "a stub named pytest exiting 5 exits 2 (pytest exit), after a verified restore" \
  || bad "a pytest exit 5 was not refused ($why) — the pytest-exit arm refuses only some of 2-5"
arm_pytest_exit2 "$VALIDATOR" \
  && ok "the same stub exiting 2 exits 2 (pytest exit)" \
  || bad "a stub pytest exit 2 was not refused ($why)"
arm_pytest_stub_kill "$VALIDATOR" \
  && ok "the same stub exiting 1 exits 0 (PROVEN), so the stub is read as pytest and a test failure is a kill" \
  || bad "a stub pytest exit 1 was not PROVEN ($why)"
arm_later_pytest_word "$VALIDATOR" \
  && ok "a make-style argv with pytest as a LATER word, real kill exiting 2, exits 0 (detection is anchored)" \
  || bad "a later argv word 'pytest' was read as a pytest runner ($why) — a real kill was refused"
arm_dash_m_pytest "$VALIDATOR" \
  && ok "the same runner with a '-m pytest' pair exits 2 (the anchored detector still reads -m pytest)" \
  || bad "a '-m pytest' argv was not read as pytest ($why)"
arm_marker_refused "$VALIDATOR" \
  && ok "a mutant refused by --syntax-check never runs the suite: the marker shows the baseline run only" \
  || bad "a refused mutant ran the suite ($why)"
arm_marker_control "$VALIDATOR" \
  && ok "CONTROL: the marker counts the mutated run (a parsing kill leaves 2 runs)" \
  || bad "FIXTURE BROKEN — the marked test did not record two runs on a parsing kill ($why); the marker arm is vacuous"
arm_ws_syntax_check "$VALIDATOR" \
  && ok "--syntax-check of only whitespace exits 2 as usage, target untouched" \
  || bad "--syntax-check ' ' did not refuse as usage ($why) — bash 3.2 expands an empty SC_ARGV under set -u"

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

if [ "$HAVE_PY" -eq 1 ]; then
  arm_py_syntax "$VALIDATOR" tip \
    && ok "a .py syntax-error mutation exits 2 (parse) and the target restores byte-identical" \
    || bad "a .py syntax-error mutation was not refused by the parse arm ($why) — a SyntaxError was graded as a kill"
  arm_py_return "$VALIDATOR" tip \
    && ok "a module-level 'return 1' under a plain python runner exits 2 (compile() rejects what ast.parse accepts)" \
    || bad "a module-level 'return 1' was not refused by the parse arm ($why)"
  arm_py_badbase "$VALIDATOR" tip \
    && ok "a baseline that does not compile leaves the parse arm off: a killing mutation still exits 0" \
    || bad "a non-compiling baseline with a killing mutation did not exit 0 with 'parse: not checked (baseline does not compile)' ($why) — the parse check is not differential"
  # A parse refusal never runs the suite either: the runner appends to a marker, so the
  # refused run leaves the baseline's one line.
  pmd="$(pyworld marker 'def f():\n    return 2\n')"; rm -f "$WORK/pmarker"
  vrun "$VALIDATOR" "$pmd/m.py" 1 'def f(:' bash -c 'printf "run\n" >> "$1"; python3 "$2"' marker "$WORK/pmarker" "$pmd/t.py"
  [ "$rc" -eq 2 ] && grep -q 'UNEVALUABLE (parse)' <<<"$out" && [ "$(lines_of "$WORK/pmarker")" -eq 1 ] \
    && ok "a mutant refused by the parse arm never runs the suite: the marker shows the baseline run only" \
    || bad "a parse-refused mutant ran the suite (exit $rc, $(lines_of "$WORK/pmarker") run(s))"
else
  skip "python3 not found — the .py parse arms (syntax error, module-level return, non-compiling baseline, parse marker) did NOT run"
fi
if [ "$HAVE_PYTEST" -eq 1 ]; then
  arm_pytest_collect "$VALIDATOR" tip \
    && ok "a pytest collection error on a mutant that compiles exits 2 (pytest exit 2 is not a test failure)" \
    || bad "a pytest collection error was graded as a kill ($why)"
  arm_pytest_green "$VALIDATOR" tip \
    && ok "a pytest run that stays GREEN under mutation still exits 1 (UNPROVEN outranks the pytest-exit arm)" \
    || bad "a GREEN pytest mutated run did not exit 1 ($why)"
  arm_pytest_kill "$VALIDATOR" tip \
    && ok "a pytest assertion failure (exit 1) under mutation still exits 0 (PROVEN)" \
    || bad "a pytest assertion failure was not PROVEN ($why) — the pytest-exit arm refuses exit 1"
else
  skip "pytest not importable by python3 — the pytest-exit arms did NOT run"
fi

# --- MUTANTS of the parse, syntax-check and pytest-exit arms ----------------------------
# mkmut <name> <producer-rc> -- checks the copy already written to $MUT/<name>.sh. Called
# in THIS shell, never as a pipeline stage, so its `bad` reaches $fails: a lost anchor must
# turn the fixture red, not print FIXTURE BROKEN beside a PASS. Refuses a producer that
# failed (a dying sed, an anchor matched other than once), an empty copy, and a copy
# identical to the validator (matched nothing).
mkmut() {
  if [ "$2" -ne 0 ] || [ ! -s "$MUT/$1.sh" ] || cmp -s "$VALIDATOR" "$MUT/$1.sh"; then
    bad "FIXTURE BROKEN: mutant $1 DID NOT APPLY (producer exit $2), so its assertion is unproven"
    return 1
  fi
}
# insert_after <anchor> <line>: print <line> after the one line starting with <anchor>;
# exits 1 unless the anchor matched exactly once.
insert_after() {
  A="$1" L="$2" awk 'BEGIN { n = 0 } { print } index($0, ENVIRON["A"]) == 1 { print ENVIRON["L"]; n++ } END { if (n != 1) exit 1 }' "$VALIDATOR"
}

# M4: syntax-check refusal exits 2 BEFORE the restore. The EXIT trap still restores the
# file, so rc and the bytes on disk are both right; only the printed verified restore is
# missing, and that line is what the arm requires.
insert_after '  REFUSED="syntax-check"' '  exit 2' > "$MUT/m4.sh"; prc=$?
if mkmut m4 "$prc"; then
  vrun "$MUT/m4.sh" --syntax-check 'bash -n' "$SUT" 2 "$SH_BROKEN" bash "$WORK/disc.sh"
  [ "$rc" -eq 2 ] && [ "$(cksum < "$SUT")" = "$BEFORE" ] && ! grep -q '^  restore:    byte-identical$' <<<"$out" \
    && ok "MUTANT 4: a syntax-check refusal exiting before the restore prints no verified restore (assertion 8 kills it)" \
    || bad "MUTANT 4 (exit 2 before restore, syntax-check) exited $rc with a verified-restore line — assertion 8 cannot see the ordering"
fi

if [ "$HAVE_PY" -eq 1 ]; then
  # M5: ast.parse instead of compile().
  # Each mutant: the KILL arm runs first and its $why is captured before the near-miss arm
  # (which must still hold) overwrites it.
  sed 's@compile(open(sys.argv\[1\], "rb").read(), sys.argv\[1\], "exec")@__import__("ast").parse(open(sys.argv[1], "rb").read(), sys.argv[1])@' \
    "$VALIDATOR" > "$MUT/m5.sh"; prc=$?
  if mkmut m5 "$prc"; then
    if ! arm_py_return "$MUT/m5.sh" m5; then kwhy="$why"
      if arm_py_syntax "$MUT/m5.sh" m5; then
        ok "MUTANT 5: ast.parse in place of compile() passes the syntax-error arm and is killed by the module-level return arm ($kwhy)"
      else bad "MUTANT 5 (ast.parse) also failed the syntax-error arm ($why) — the kill is entangled"; fi
    else bad "MUTANT 5 (ast.parse) survived the module-level return arm"; fi
  fi
  # M6: non-differential — the baseline gate removed, the arm always on for *.py.
  sed 's@^    elif py_compiles "\$TARGET" baseline; then$@    elif true; then@' \
    "$VALIDATOR" > "$MUT/m6.sh"; prc=$?
  if mkmut m6 "$prc"; then
    if ! arm_py_badbase "$MUT/m6.sh" m6; then kwhy="$why"
      if arm_py_syntax "$MUT/m6.sh" m6; then
        ok "MUTANT 6: a non-differential parse check refuses a killing mutation over a non-compiling baseline ($kwhy) and is killed"
      else bad "MUTANT 6 (no baseline gate) also failed the syntax-error arm ($why) — the kill is entangled"; fi
    else bad "MUTANT 6 (no baseline gate) survived the non-compiling-baseline arm"; fi
  fi
  # M7: the mutant check reads the BACKUP, which always compiles when the baseline did.
  sed 's@! py_compiles "\$TARGET" mutant; then@! py_compiles "$BACKUP" mutant; then@' \
    "$VALIDATOR" > "$MUT/m7.sh"; prc=$?
  if mkmut m7 "$prc"; then
    if ! arm_py_syntax "$MUT/m7.sh" m7; then kwhy="$why"
      if arm_py_badbase "$MUT/m7.sh" m7; then
        ok "MUTANT 7: checking the backup instead of the mutant lets a syntax error through ($kwhy) and is killed"
      else bad "MUTANT 7 (backup checked) also failed the non-compiling-baseline arm ($why) — the kill is entangled"; fi
    else bad "MUTANT 7 (backup checked) survived the syntax-error arm"; fi
  fi
  # M8: parse refusal exits 2 BEFORE the restore. The EXIT trap still puts the bytes back
  # and the exit is still 2, so the printed verified restore is the only thing that kills it.
  insert_after '  REFUSED="parse"' '  exit 2' > "$MUT/m8.sh"; prc=$?
  if mkmut m8 "$prc"; then
    m8d="$(pyworld m8 'def f():\n    return 2\n')"; m8before="$(cksum < "$m8d/m.py")"
    vrun "$MUT/m8.sh" "$m8d/m.py" 1 'def f(:' python3 "$m8d/t.py"
    if [ "$rc" -eq 2 ] && [ "$(cksum < "$m8d/m.py")" = "$m8before" ] \
       && ! grep -q '^  restore:    byte-identical$' <<<"$out" && ! arm_py_syntax "$MUT/m8.sh" m8b; then
      ok "MUTANT 8: a parse refusal exiting before the restore keeps exit 2 and the bytes, prints no verified restore, and is killed"
    else
      bad "MUTANT 8 (exit 2 before restore, parse) exited $rc — the syntax-error arm's restore conjunct cannot see the ordering"
    fi
  fi
else
  skip "python3 not found — mutants 5-8 of the parse arm did NOT run"
fi
if [ "$HAVE_PYTEST" -eq 1 ]; then
  # M9: the pytest arm takes precedence over exit 0, so a GREEN pytest run reads UNEVALUABLE.
  sed 's@^if \[ "\$mut_rc" -eq 0 \]; then$@if [ "$mut_rc" -eq 0 ] \&\& [ "$IS_PYTEST" -eq 0 ]; then@' \
    "$VALIDATOR" > "$MUT/m9.sh"; prc=$?
  if mkmut m9 "$prc"; then
    if ! arm_pytest_green "$MUT/m9.sh" m9; then kwhy="$why"
      if arm_pytest_collect "$MUT/m9.sh" m9; then
        ok "MUTANT 9: a pytest arm treating exit 0 as UNEVALUABLE is killed by the GREEN-under-pytest arm ($kwhy)"
      else bad "MUTANT 9 (pytest exit 0 refused) also failed the collection-error arm ($why) — the kill is entangled"; fi
    else bad "MUTANT 9 (pytest exit 0 refused) survived the GREEN-under-pytest arm"; fi
  fi
else
  skip "pytest not importable by python3 — mutant 9 of the pytest-exit arm did NOT run"
fi

# --- MUTANTS 10-14: the tip adversary's wrong fixes. No python needed. -------------------
# mutant_pair <name> <kill-arm> <near-miss-arm> <label>: the kill arm must FAIL on the
# mutant, and the near-miss arm (one property apart) must still HOLD on it.
mutant_pair() {
  if ! "$2" "$MUT/$1.sh"; then kwhy="$why"
    if "$3" "$MUT/$1.sh"; then ok "MUTANT ${1#m}: $4 is killed by $2 ($kwhy); $3 still holds"
    else bad "MUTANT ${1#m} ($4) also failed $3 ($why) — the kill is entangled"; fi
  else bad "MUTANT ${1#m} ($4) survived $2"; fi
}
# M10 (z5): the pytest-exit arm applied to every runner.
sed 's@^if \[ "\$IS_PYTEST" -eq 1 \] && \[ "\$mut_rc" -ne 1 \]; then$@if [ "$mut_rc" -ne 1 ]; then@' \
  "$VALIDATOR" > "$MUT/m10.sh"; prc=$?
mkmut m10 "$prc" && mutant_pair m10 arm_nonpytest_exit2 arm_pytest_exit5 "the pytest-exit arm applied to every runner"
# M11 (z3): only pytest exit 2 refused.
sed 's@^if \[ "\$IS_PYTEST" -eq 1 \] && \[ "\$mut_rc" -ne 1 \]; then$@if [ "$IS_PYTEST" -eq 1 ] \&\& [ "$mut_rc" -eq 2 ]; then@' \
  "$VALIDATOR" > "$MUT/m11.sh"; prc=$?
mkmut m11 "$prc" && mutant_pair m11 arm_pytest_exit5 arm_pytest_exit2 "refusing only pytest exit 2"
# M12 (z4): the suite still runs on a refused mutant (the verdict is unchanged).
sed 's@^if \[ -z "\$REFUSED" \]; then$@if true; then@' "$VALIDATOR" > "$MUT/m12.sh"; prc=$?
mkmut m12 "$prc" && mutant_pair m12 arm_marker_refused arm_marker_control "running the suite on a refused mutant"
# M13: unanchored detection, here keyed on the LAST word instead of the first.
sed 's|^case "\${TEST_CMD\[0\]##\*/}" in$|case "${TEST_CMD[${#TEST_CMD[@]}-1]##*/}" in|' \
  "$VALIDATOR" > "$MUT/m13.sh"; prc=$?
mkmut m13 "$prc" && mutant_pair m13 arm_later_pytest_word arm_pytest_stub_kill "pytest detected on a word other than the first"
# M14: the whitespace-only --syntax-check guard removed.
sed 's|^  if \[ "\${#SC_ARGV\[@\]}" -eq 0 \]; then$|  if false; then|' "$VALIDATOR" > "$MUT/m14.sh"; prc=$?
mkmut m14 "$prc" && mutant_pair m14 arm_ws_syntax_check arm_marker_control "no guard on a whitespace-only --syntax-check"

echo
if [ "$fails" -eq 0 ]; then echo "mutation-red-replay: PASS"; exit 0; fi
echo "mutation-red-replay: $fails assertion(s) FAILED" >&2
exit 1
