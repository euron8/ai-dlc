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
echo "HERMETIC-CONSUMED $VALIDATOR"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
skip() { printf '  SKIP  %s\n' "$1"; }
# CAPGUARD-BEGIN
# THE HOST CAPABILITIES, decided by LAYOUT (BL-940). pytest importable by python3 and a UTF-8 locale in
# `locale -a` gate arms below. On a consumer the host is not ours to assume, so a missing one SKIPs the arms
# that need it, naming them. In the distribution a SKIP would move the counted start total with the box
# (447 with both, 414 without pytest, 422 without the locale), and the invocation judge would then fail a
# fixture that printed PASS. So the distribution refuses: FIXTURE BROKEN, exit 2, before the first arm
# (after seed.sh, so a refused run carries 2 counted rows, run.sh and seed.sh; hermetic-run.sh applies no J3 to an rc-2 run),
# naming every absent capability in one refusal, with the remedy. The layout is the POSITION of this directory, never a walk-up for
# core/ markers: the sandbox copies only the declared inputs, which name neither marker directory.
# derive_layout <fixture dir> -> sets LAYOUT to dist, consumer or NEITHER
derive_layout() {
  local fname="${1##*/}" d
  LAYOUT=NEITHER
  d="$(dirname "$1")"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ "$d/core/fixtures/$fname" = "$1" ]; then LAYOUT=dist; return 0; fi
    if [ "$d/tests/fixtures/$fname" = "$1" ]; then LAYOUT=consumer; return 0; fi
    d="$(dirname "$d")"
  done
  return 0
}
# cap_probe -> sets HAVE_PY, HAVE_PYTEST and U8 from this host. U8 is a UTF-8 locale for s11: the fixture sets no
# locale, so under a C-locale hook env the parse would not be exercised under a UTF-8 locale; the seed pins one
# itself. The first match is taken by awk (head is not a declared tool).
cap_probe() {
  local _locs
  HAVE_PY=0; command -v python3 >/dev/null 2>&1 && HAVE_PY=1
  HAVE_PYTEST=0
  [ "$HAVE_PY" -eq 1 ] && python3 -c 'import pytest' >/dev/null 2>&1 && HAVE_PYTEST=1
  U8=""
  if command -v locale >/dev/null 2>&1; then
    _locs="$(locale -a 2>/dev/null)" || _locs=""
    if grep -qx 'en_US.UTF-8' <<<"$_locs"; then U8=en_US.UTF-8
    else U8="$(grep -iE '\.utf-?8$' <<<"$_locs" | awk 'NR == 1')" || U8=""; fi
  fi
  return 0
}
# cap_py_where -> the interpreter the sandbox runs and its own site-packages directories
cap_py_where() {
  python3 -c 'import sys, site; print(sys.executable + "; its site-packages: " + ", ".join(site.getsitepackages()))' 2>/dev/null \
    || printf 'python3 could not report its interpreter'
}
# cap_guard -> 0, or the refusal on stdout and 2. Reads LAYOUT, HAVE_PY, HAVE_PYTEST and U8. Every absent
# capability is named in the one refusal, so a box missing both learns both in one push.
cap_guard() {
  local miss=""
  [ "$LAYOUT" = dist ] || return 0
  if [ "$HAVE_PYTEST" -ne 1 ]; then
    if [ "$HAVE_PY" -eq 1 ]; then CAP_PY="$(cap_py_where)"; else CAP_PY="no python3 on the sandbox PATH"; fi
    miss="pytest"
    printf 'mutation-red-replay: FIXTURE BROKEN -- capability absent: pytest is not importable by python3 (%s). The pytest-exit arms and seeds s1-s11 would not run. Remedy: the sandbox runs the first python3 found on READSET_TOOL_DIRS in .githooks/pre-push, which already lists /opt/homebrew/bin first, so on macOS installing Homebrew python3 and making pytest importable by it is enough, and nothing tracked needs editing. Installing pytest into the site-packages named above also works, but those may be root-owned (needing sudo) or, for a Homebrew python, marked EXTERNALLY-MANAGED (PEP 668). A user-site install (pip --user) is invisible here: the sandbox HOME is private.\n' "$CAP_PY"
  fi
  if [ -z "$U8" ]; then
    miss="$miss${miss:+ and }a UTF-8 locale"
    printf 'mutation-red-replay: FIXTURE BROKEN -- capability absent: no UTF-8 locale is listed by `locale -a`. s11 and case E of the capture round-trip would not run. Remedy: install or enable a UTF-8 locale (for example en_US.UTF-8 or C.UTF-8) so `locale -a` lists it.\n'
  fi
  [ -n "$miss" ] || return 0
  printf 'mutation-red-replay: FIXTURE BROKEN -- absent: %s. In the distribution a missing capability is a broken fixture, not a skip: its arms would not run, and the counted start total would move with the box.\n' "$miss"
  return 2
}
# CAPGUARD-END
# THE CALL REGION, from the line after CAPGUARD-END through CAPCALL-END. The cap_call cells below evaluate exactly
# these lines, so a call that is deleted, disabled, hidden in a heredoc, preceded by an override or moved past the
# marker is seen by its BEHAVIOUR, not its text. Keep anything that is not the layout, the probe and the guard out.
derive_layout "$HERE"
if [ "$LAYOUT" = NEITHER ]; then
  echo "mutation-red-replay: FIXTURE BROKEN -- layout: $HERE is neither <root>/core/fixtures/mutation-red-replay (distribution) nor <root>/tests/fixtures/mutation-red-replay (consumer), so whether a missing capability refuses or skips is undecidable" >&2
  exit 2
fi
echo "layout: $LAYOUT (position form)"
cap_probe
cap_guard >&2 || exit 2
# CAPCALL-END

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

# --- the arms of assertions 1-5, 7-9 and the replacement-is-data case, as functions ----------
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
PYTEST=(python3 -m pytest -q -p no:cacheprovider)
skip() { printf '  SKIP  %s\n' "$1"; }

# Each python arm is a function of the validator.
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
# U8 (a UTF-8 locale for s11 and case E) is set by cap_probe, in the call region above.
arm_s11() { # an all-skipped run whose log carries a non-UTF-8 byte (\xff under -s) -> 2
  local d; d="$(skworld "s11-$2" "$M_F" 'import sys, pytest\nfrom m import f\nsys.stdout.buffer.write(b"\\xff\\n"); sys.stdout.flush()\n@pytest.mark.skip(reason="x")\ndef test_f():\n    assert f() == 2\n')"
  out="$(LC_ALL="$U8" bash "$1" "$d/m.py" 2 '    return 3' "${PYTEST[@]}" -s "$d/test_m.py" 2>&1)"; rc=$?
  why="exit $rc"
  [ "$rc" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran)' <<<"$out"
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
# discriminates only on a multi-word argument. U also runs the `test:`
# conjuncts; its test argv is single-token.
# R is the red-baseline world, not the no-op one, because its refusal sits later in the flow:
# a `$ ` printf moved anywhere above the baseline run prints on it. H is
# the LATEST pre-restore refusal, the restore verification itself, so a `$ ` printf placed
# anywhere above it prints on it, including after the baseline run.
# The tilde cases carry their words in the test argv, so both lines render them. bash 3.2's
# %q leaves `~` bare and the child bash in rt_split would expand it. T: a word-leading `~root`
# (root exists on every macOS and Linux box; a user that does not exist is not expanded and
# would discriminate nothing), `~+`, and the mid-word `a~root` that never expands. X: a `~`
# after `=` and after `:` (`x=~root`, `FOO=a:~/b`), which a leading-only escape misses
# D: `~root<TAB>z`, which %q puts in $'...' form, where `\~` is NOT an escape,
# so an escape applied to every word breaks it.
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

# The cases of the capture round-trip, each an arm of its own. Each sets $why and returns 0 when its case holds.
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
ARMS="$ARMS marker_refused marker_control ws_syntax_check stub_note"
ARMS="$ARMS py_syntax py_return py_badbase py_marker pytest_collect pytest_green pytest_kill"
ARMS="$ARMS s1 s2 s3 s4 s5 s6 s7 s8 s9 s9b s10 s11 $RT_ARMS"
for _a in $ARMS; do
  declare -F "arm_$_a" >/dev/null 2>&1 || { echo "FIXTURE BROKEN: arm $_a is registered but arm_$_a is not defined" >&2; exit 2; }
done
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

# THE GUARD'S OWN CELLS. The CAPGUARD span above is extracted and evaluated in a subshell with the probes
# overridden, so the refusal is seen to fire on a box that HAS both capabilities, and no cell starts a
# process the invocation counter counts. capcell <span> <layout> <have_pytest> <u8> -> "<rc>|<output>"
cap_span() { awk '/^# CAPGUARD-BEGIN$/ { f = 1; next } /^# CAPGUARD-END$/ { f = 0 } f' "$HERE/run.sh"; }
capcell() {
  ( eval "$1" || exit 9
    cap_py_where() { printf 'PROBE-PY'; }
    LAYOUT="$2"; HAVE_PY=1; HAVE_PYTEST="$3"; U8="$4"
    o="$(cap_guard 2>&1)"; printf '%s|%s' "$?" "$o" )
}
# laycell <span> <fixture dir> -> the LAYOUT derive_layout sets for that path (string work only)
laycell() { ( eval "$1" || exit 9; derive_layout "$2"; printf '%s' "$LAYOUT" ); }
CAP_SPAN="$(cap_span)"
case "$CAP_SPAN" in *"cap_guard()"*"derive_layout()"*|*"derive_layout()"*"cap_guard()"*) ;;
  *) echo "mutation-red-replay: FIXTURE BROKEN -- the CAPGUARD span is empty or lost cap_guard/derive_layout" >&2; exit 2 ;; esac
r="$(capcell "$CAP_SPAN" dist 0 en_US.UTF-8)"
if [ "${r%%|*}" = 2 ] && grep -qF 'capability absent: pytest is not importable by python3 (PROBE-PY)' <<<"$r" \
   && grep -qF 'READSET_TOOL_DIRS' <<<"$r"; then
  ok "cap_dist_pytest -- in the distribution, pytest absent refuses (exit 2) naming the capability, the interpreter and the remedy"
else bad "cap_dist_pytest -- in the distribution, pytest absent did not refuse with the named remedy (got ${r%%|*}: ${r#*|})"; fi
r="$(capcell "$CAP_SPAN" dist 1 "")"
if [ "${r%%|*}" = 2 ] && grep -qF 'capability absent: no UTF-8 locale is listed by `locale -a`' <<<"$r"; then
  ok "cap_dist_locale -- in the distribution, no UTF-8 locale refuses (exit 2) naming it and the remedy"
else bad "cap_dist_locale -- in the distribution, no UTF-8 locale did not refuse with the named remedy (got ${r%%|*}: ${r#*|})"; fi
r="$(capcell "$CAP_SPAN" dist 0 "")"
if [ "${r%%|*}" = 2 ] && grep -qF 'pytest is not importable' <<<"$r" && grep -qF 'no UTF-8 locale is listed' <<<"$r" \
   && grep -qF 'absent: pytest and a UTF-8 locale.' <<<"$r"; then
  ok "cap_dist_both -- in the distribution, both absent are named in ONE refusal (exit 2)"
else bad "cap_dist_both -- both absent were not named in one refusal (got ${r%%|*}: ${r#*|})"; fi
# THE CALL SITE, BY BEHAVIOUR. cap_region <file text> prints the lines after CAPGUARD-END through CAPCALL-END. callcell
# evaluates the span and then that region in a subshell, with the probe and the interpreter report overridden
# AFTER the span defines them and HERE set to a distribution path, so the region's own derive_layout derives dist.
# No bash is started. callcell <file text> <have_pytest> <u8> -> "<rc>|<output>"
cap_region() { awk '/^# CAPGUARD-END$/ { f = 1; next } f { print } f && /^# CAPCALL-END$/ { exit }' <<<"$1"; }
callcell() {
  ( local_span="$(awk '/^# CAPGUARD-BEGIN$/ { f = 1; next } /^# CAPGUARD-END$/ { f = 0 } f' <<<"$1")"
    local_reg="$(cap_region "$1")"
    case "$local_reg" in *"# CAPCALL-END") ;; *) printf '9|no CAPCALL-END after CAPGUARD-END'; exit 0 ;; esac
    eval "$local_span" || { printf '9|span did not evaluate'; exit 0; }
    _fpt="$2"; _fu8="$3"
    cap_probe() { HAVE_PY=1; HAVE_PYTEST="$_fpt"; U8="$_fu8"; }
    cap_py_where() { printf 'PROBE-PY'; }
    HERE=/x/r/core/fixtures/mutation-red-replay
    o="$(eval "$local_reg" 2>&1)"; printf '%s|%s' "$?" "$o" )
}
CC_SELF="$(cat "$HERE/run.sh")"
r="$(callcell "$CC_SELF" 0 en_US.UTF-8)"
if [ "${r%%|*}" = 2 ] && grep -qF 'capability absent: pytest is not importable by python3 (PROBE-PY)' <<<"$r" && grep -qF 'layout: dist' <<<"$r"; then
  ok "cap_called -- the shipped call region, evaluated with pytest forced absent in the distribution, refuses (exit 2) naming it"
else bad "cap_called -- the shipped call region did not refuse a forced-absent pytest in the distribution (got ${r%%|*}: ${r#*|})"; fi
r="$(callcell "$CC_SELF" 1 en_US.UTF-8)"
if [ "$r" = "0|layout: dist (position form)" ]; then ok "cap_called_present -- the shipped call region with both capabilities forced present runs through (exit 0)"
else bad "cap_called_present -- the shipped call region refused a host with both capabilities (got ${r%%|*}: ${r#*|})"; fi
r="$(capcell "$CAP_SPAN" consumer 0 "")"
if [ "$r" = "0|" ]; then ok "cap_consumer -- on a consumer, both capabilities absent pass the guard silently (the arms SKIP instead)"
else bad "cap_consumer -- on a consumer the guard did not stand down (got ${r%%|*}: ${r#*|})"; fi
r="$(capcell "$CAP_SPAN" dist 1 en_US.UTF-8)"
if [ "$r" = "0|" ]; then ok "cap_dist_present -- in the distribution, both capabilities present pass the guard"
else bad "cap_dist_present -- the guard refused a host with both capabilities (got ${r%%|*}: ${r#*|})"; fi
if [ "$(laycell "$CAP_SPAN" /x/r/core/fixtures/mutation-red-replay)" = dist ]; then ok "lay_dist -- <root>/core/fixtures/<name> derives dist"
else bad "lay_dist -- <root>/core/fixtures/<name> did not derive dist"; fi
if [ "$(laycell "$CAP_SPAN" /x/r/tests/fixtures/mutation-red-replay)" = consumer ]; then ok "lay_consumer -- <root>/tests/fixtures/<name> derives consumer"
else bad "lay_consumer -- <root>/tests/fixtures/<name> did not derive consumer"; fi
if [ "$(laycell "$CAP_SPAN" /x/r/fixtures/mutation-red-replay)" = NEITHER ]; then ok "lay_neither -- a path in neither layout derives NEITHER, never a default"
else bad "lay_neither -- a path in neither layout did not derive NEITHER"; fi
# armrun <arm> <validator> <world tag> -> the arm's own status, $why set
armrun() { "arm_$1" "$2" "$3"; }
# live <arm> <ok text> <failure text>: drive the arm on the shipped validator.
live() {
  if armrun "$1" "$VALIDATOR" tip; then ok "$2"
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
live amp "a replacement of '&' is a literal to the shipped rewrite (exit 0)" \
  "a replacement of '&' did not exit 0 — the replacement is not being treated as data"
[ "$(cksum < "$SUT")" = "$BEFORE" ] \
  && ok "the target is byte-identical after the replays (PROVEN, UNPROVEN and the refusals)" \
  || bad "the target did not come back byte-identical — the replay left mutated source on disk"
live a7_hard "a restore that does not verify exits 3 and leaves the pre-mutation bytes on disk at the path it prints" \
  "a target that could not be restored did not exit 3 with an intact backup — a mutated tree was reported as a completed replay"

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
[ -n "$U8" ] || skip "no UTF-8 locale — case E of the capture round-trip did NOT run"

# arm_argv_roundtrip <validator> <live>: the ten capture cases (flags, --, a multi-word -k, a
# quoted replacement, the single-token control, a RED refusal exiting 2, a HARD refusal exiting 3,
# an UNPROVEN exit 1, the tilde words, a multibyte replacement), each an arm of its own. The
# single-token control is part of it: it must round-trip too, which is what proves the test-argv
# conjunct discriminates only on a multi-word argument.
arm_argv_roundtrip() {
  local r all="" bad_n=0
  for r in $RT_ARMS; do
    arm_avail "$r" || continue
    if ! armrun "$r" "$1" tip; then bad_n=1; all="$all $why"; fi
  done
  why="$all"
  [ "$bad_n" -eq 0 ]
}
arm_argv_roundtrip "$VALIDATOR" live \
  && ok "arm_argv_roundtrip: the \`\$ \` line and the \`test:\` line replay, through bash, to the exact argv (flags, --, a multi-word -k, a quoted replacement, the single-token control, an UNPROVEN exit 1, the tilde words and a multibyte replacement), a RED-baseline refusal exits 2 and a HARD refusal exits 3, each with no \`\$ \` line" \
  || bad "arm_argv_roundtrip: the capture does not replay to its own argv, or a refusal printed one ($why) — a committed capture is a command that does not run"
# The `$ ` line must name the validator by the path it was invoked as: only a second path tells that from a fixed one.
CTL_DIR="$WORK/control"
mkdir -p "$CTL_DIR"
cp "$VALIDATOR" "$CTL_DIR/control.sh"
arm_argv_roundtrip "$CTL_DIR/control.sh" copy \
  && ok "arm_argv_roundtrip holds on the validator invoked from \$CTL_DIR, \`\$ \` naming the path as invoked" \
  || bad "arm_argv_roundtrip fails on the validator invoked from \$CTL_DIR ($why) — the \`\$ \` line does not name the path as invoked"

echo
report_end mutation-red-replay
