#!/usr/bin/env bash
# fixture-drivability — assert the consumer-side I20 cannot go quiet.
#
# THE DEFECT THIS EXISTS TO CATCH. `core/git-hooks/pre-push` skips a fixture directory
# with no `run.sh` and prints nothing for the skip, so the directory is indistinguishable
# from one that passed. I20 catches that where core AUTHORS fixtures and its own header
# says it stops there; H1 catches it for fixtures a `kind: check` entry binds, and on the
# reference consumer that binding set is empty. Between the two, 28 of the reference
# consumer's 29 own fixture directories were covered by nothing.
#
# So the assertions are about the CHECK, not about today's tree. What must hold is that
# each of the two undeclared shapes FAILS and is NAMED, that the exemption still passes
# (core ships two fixtures that depend on it, into every consumer), and that a run over an
# empty subject set says so in words instead of exiting 0 in silence.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS. install.sh splits what shares a parent here: core/fixtures/ + core/scripts/
# become tests/fixtures/ + scripts/ai-dlc/. Every candidate is rooted at this file's own
# location and both layouts are named — I33 fails the build on a fixture that reaches a
# core subtree by walking up from a path some other resolver produced.
SCRIPT=""
for cand in \
  "$HERE/../../scripts/validate-fixture-drivability.sh" \
  "$HERE/../../../scripts/ai-dlc/validate-fixture-drivability.sh" \
  "$HERE/../../core/scripts/validate-fixture-drivability.sh"; do
  [ -f "$cand" ] && SCRIPT="$cand" && break
done

if [ -z "$SCRIPT" ]; then
  echo "FIXTURE ERROR: could not locate validate-fixture-drivability.sh from $HERE" >&2
  exit 2
fi

echo "HERMETIC-CONSUMED $(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"

ROOT="$(bash "$HERE/seed.sh" "$SCRIPT")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
WORK="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$WORK"' EXIT
FX="$ROOT/tests/fixtures"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# IN PROCESS (BL-878). The script is loaded ONCE with lib/inproc.sh's inproc_load (its source guard returns after
# defining vfd_main) and every assertion asks vfd_main through inproc_run, in a subshell made to look like a fresh
# `bash validate-fixture-drivability.sh`. The program runs only in the cli cells (cells.decl).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped script, and
# sourcing a pre-wrap script would run its whole body. So the shape is checked first, on its two halves: neither the
# `vfd_main() {` line nor the column-0 source guard is a script that predates the wrap, which prints SKIP and exits 0
# (FIXTURE BROKEN in the distribution) -- never an ok. Exactly one half is a respelled script this fixture cannot
# drive, which FAILS. An unreadable script is FIXTURE ERROR.
vfd_def=0; vfd_guard=0
grep -qxF 'vfd_main() {' "$SCRIPT"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SCRIPT (grep exit $_gx) -- an unreadable script is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || vfd_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$SCRIPT"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SCRIPT (grep exit $_gx) -- an unreadable script is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || vfd_guard=1
if [ "$vfd_def$vfd_guard" = 00 ]; then echo "SKIP: $SCRIPT predates the in-process wrap"; fx_skip_exit "$HERE"; fi
if [ "$vfd_def$vfd_guard" != 11 ]; then
  bad "$SCRIPT carries one half of the in-process wrap (vfd_main line: $vfd_def, column-0 source guard: $vfd_guard) -- a respelled script this fixture cannot drive"
  report_end fixture-drivability
fi
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$SCRIPT" || { echo "FIXTURE BROKEN: sourcing $SCRIPT defined nothing" >&2; exit 2; }
declare -F vfd_main >/dev/null || { echo "FIXTURE BROKEN: sourcing $SCRIPT defined no vfd_main" >&2; exit 2; }

echo "fixture-drivability:"

# --- Assertion 0: SANITY ------------------------------------------------------
# The seed must be readable and the script must run. If the harness itself is broken,
# every "it failed as expected" below is a false pass — a script that dies on startup
# emits nothing and passes every negative assertion at once.
out="$(inproc_run "$SCRIPT" vfd_main --dir "$FX" 2>&1)"; rc=$?
if grep -q 'fixture directories : 5' <<<"$out"; then
  ok "the seed presents 5 directories and the loose MANIFEST file is not counted as one"
else
  bad "FIXTURE BROKEN — the script did not report the seeded directory count; every assertion below would be a false pass"
  echo; echo "fixture-drivability: $fails assertion(s) FAILED" >&2; exit 2
fi

# --- Assertion 1: THE BARE HOLE FAILS AND IS NAMED ----------------------------
# `delta` has no run.sh and no README. This is the state the push hook skips silently.
if [ "$rc" -ne 0 ] && grep -q "fixture 'delta' has neither a run.sh nor a README.md" <<<"$out"; then
  ok "a directory with no driver and no README FAILS and is named"
else
  bad "a directory with no driver and no README did not fail by name — the push hook would skip it and say nothing"
fi

# --- Assertion 2: THE NEAR MISS FAILS IN ITS OWN WORDS ------------------------
# `echo` has a README that says something else. Asserted on the SECOND message, not on
# the word "FAIL": the two arms report different authoring mistakes.
if grep -q "fixture 'echo' has no run.sh and its README.md does not declare the exemption" <<<"$out"; then
  ok "a README that does not declare the exemption FAILS in its own words"
else
  bad "a README with no exemption declaration was accepted, or reported in the bare-hole arm's words"
fi

# --- Assertion 3: THE EXEMPTION STILL PASSES ----------------------------------
# The state core's own two driverless fixtures are in. This arm is the one whose
# regression is invisible to the distribution and expensive to every consumer.
if grep -q 'declared undrivable: 1' <<<"$out" && ! grep -q "fixture 'charlie'" <<<"$out"; then
  ok "a README carrying the exemption marker passes (core ships two fixtures that depend on this)"
else
  bad "the declared exemption did not pass — core's own driverless fixtures would fail every consumer's push"
fi

# --- Assertion 4: A COMPLIANT TREE PASSES -------------------------------------
# The false-positive arm. Remove the two undeclared directories and nothing may report.
cp -R "$FX" "$WORK/clean"
rm -rf "$WORK/clean/delta" "$WORK/clean/echo"
if inproc_run "$SCRIPT" vfd_main --dir "$WORK/clean" >/dev/null 2>&1; then
  ok "a tree where every directory is driven or declared passes (the negatives above mean something)"
else
  bad "a fully compliant tree FAILED — the check reports on correct trees and will be turned off"
fi

# --- Assertion 5: AN EMPTY SUBJECT SET IS STATED, NOT PASSED IN SILENCE -------
# A zero is not a finding. A run that judged nothing must not be indistinguishable from a
# run that judged everything and found it well.
mkdir -p "$WORK/empty"
out_e="$(inproc_run "$SCRIPT" vfd_main --dir "$WORK/empty" 2>&1)"
if grep -q 'no fixture directories' <<<"$out_e"; then
  ok "a run over an empty subject set says so rather than exiting 0 in silence"
else
  bad "a run over an empty subject set produced no statement that it judged nothing"
fi

# --- The cli cells (cells.decl): the script run as a PROGRAM once per distinct CLI outcome --------------------------
# Each `FXCELL=<id> bash` start is compared with the in-process call on the same tree: stdout, stderr and exit
# separately, byte for byte. Outcomes: exit 1 naming the undeclared directories (cli-fail) and exit 0 on a compliant
# tree (cli-pass). Each cell also asserts its own exit code and a line of output, so two runs that both printed
# nothing cannot read as equivalent.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
eqv() { # <cell-id> <fixture dir> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  inproc_run "$SCRIPT" vfd_main --dir "$2" > "$EQ/$1.ip.out" 2> "$EQ/$1.ip.err"; echo "$?" > "$EQ/$1.ip.rc"
  FXCELL="$1" bash "$SCRIPT" --dir "$2" > "$EQ/$1.cl.out" 2> "$EQ/$1.cl.err"; echo "$?" > "$EQ/$1.cl.rc"
  cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(head -1 "$EQ/$1.ip.out")" "$(head -1 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(head -1 "$EQ/$1.cl.out")" "$(head -1 "$EQ/$1.cl.err")"; }
if eqv cli-fail "$FX" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] && grep -q "fixture 'delta'" "$EQ/cli-fail.cl.err" "$EQ/cli-fail.cl.out"; then
  ok "cli-fail: the program names the undeclared directories and exits 1 exactly as the in-process call does"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 naming 'delta' ($(eq_twin cli-fail))"; fi
if eqv cli-pass "$WORK/clean" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && grep -q '^PASS' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program passes the compliant tree exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with its PASS line ($(eq_twin cli-pass))"; fi

echo
report_end fixture-drivability
