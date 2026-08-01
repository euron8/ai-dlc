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

ROOT="$(bash "$HERE/seed.sh" "$SCRIPT")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
WORK="$(mktemp -d)"
trap 'rm -rf "$ROOT" "$WORK"' EXIT
FX="$ROOT/tests/fixtures"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "fixture-drivability:"

# --- Assertion 0: SANITY ------------------------------------------------------
# The seed must be readable and the script must run. If the harness itself is broken,
# every "it failed as expected" below is a false pass — a script that dies on startup
# emits nothing and scores as a kill for every negative assertion at once.
out="$(bash "$SCRIPT" --dir "$FX" 2>&1)"; rc=$?
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
# the word "FAIL", so assertion 1's mutation cannot satisfy this one: the two arms report
# different authoring mistakes and a check that collapsed them would still pass one.
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
if bash "$SCRIPT" --dir "$WORK/clean" >/dev/null 2>&1; then
  ok "a tree where every directory is driven or declared passes (the negatives above mean something)"
else
  bad "a fully compliant tree FAILED — the check reports on correct trees and will be turned off"
fi

# --- Assertion 5: AN EMPTY SUBJECT SET IS STATED, NOT PASSED IN SILENCE -------
# A zero is not a finding. A run that judged nothing must not be indistinguishable from a
# run that judged everything and found it well.
mkdir -p "$WORK/empty"
out_e="$(bash "$SCRIPT" --dir "$WORK/empty" 2>&1)"
if grep -q 'no fixture directories' <<<"$out_e"; then
  ok "a run over an empty subject set says so rather than exiting 0 in silence"
else
  bad "a run over an empty subject set produced no statement that it judged nothing"
fi

# --- Mutants. Each is a COPY, guarded by cmp -s, and asserts a POSITIVE outcome:
#     the mutated copy ACCEPTS a tree the shipped script rejects. Each mutant fails only
#     its own assertion — the two guards are independent branches and the tree carries a
#     distinct subject for each.
# BOTH CALLERS WRAP THIS IN `$( )` to capture the mutant's path, so a bad() here
# is captured as the return value and its fails++ dies with the subshell. The
# caller's `if` then takes the false branch, the assertion vanishes with no
# diagnostic, and the fixture still reports PASS one assertion shorter. Recorded
# to a FILE instead and read at the end, where nothing can swallow it. Same defect
# and same remedy as layer-qualifier-grain — see v0.231.0, where an unrelated
# sweep rewrote a line a mutation anchored on and this shape hid it.
MUT_UNLANDED="$WORK/mutations-that-did-not-land"
: > "$MUT_UNLANDED"
mutate() {  # <name> <sed program>
  local name="$1" prog="$2" mp="$WORK/$1.sh"
  sed "$prog" "$SCRIPT" > "$mp"
  if cmp -s "$SCRIPT" "$mp"; then
    printf '%s\n' "$name" >> "$MUT_UNLANDED"
    rm -f "$mp"
    return 1
  fi
  printf '%s' "$mp"
}

# CONTROL — an UNMUTATED copy in the same directory, run the same way. A copy that dies
# for a reason of its own (a missing relative path, an unset variable) emits nothing and
# exits non-zero, which is what a working check looks like here; without this arm, both
# mutants below could be scoring the copy mechanism rather than the mutation.
cp "$SCRIPT" "$WORK/control.sh"
if ! bash "$WORK/control.sh" --dir "$FX" >/dev/null 2>&1; then
  ok "an UNMUTATED copy still rejects the seeded tree (the mutants below are scoring the mutation, not the copy)"
else
  bad "FIXTURE BROKEN — an unmutated copy accepted a tree the original rejects; the mutants below prove nothing"
fi

# MUTANT 1 — the bare-hole branch stops recording. Everything else, including the
# near-miss branch, is left in place, so this must NOT silence 'echo'.
if mp="$(mutate m1 's@^    undeclared+=("$name")@    :@')"; then
  out_m="$(bash "$mp" --dir "$FX" 2>&1)"
  if ! grep -q "fixture 'delta'" <<<"$out_m" && grep -q "fixture 'echo'" <<<"$out_m"; then
    ok "MUTANT 1: with the no-README branch removed, 'delta' goes silent and 'echo' still reports — the branch is load-bearing and unentangled"
  else
    bad "MUTANT 1 did not isolate the no-README branch (either 'delta' still reported, or 'echo' fell silent with it)"
  fi
fi

# MUTANT 2 — the marker test always succeeds, so an undeclared README counts as exempt.
# 'delta' must still report: this arm and mutant 1's are different branches.
if mp="$(mutate m2 's@if grep -qF -- "$EXEMPT_MARKER" "${d}README.md"; then@if true; then@')"; then
  out_m="$(bash "$mp" --dir "$FX" 2>&1)"
  if ! grep -q "fixture 'echo'" <<<"$out_m" && grep -q "fixture 'delta'" <<<"$out_m"; then
    ok "MUTANT 2: with the marker test always true, 'echo' goes silent and 'delta' still reports — the marker is what makes the exemption a declaration"
  else
    bad "MUTANT 2 did not isolate the marker test (either 'echo' still reported, or 'delta' fell silent with it)"
  fi
fi

# --- CONTROL: both mutations above actually landed -----------------------------
# Each mutant is guarded by `if mp="$(mutate ...)"`, so a sed matching nothing
# takes the false branch and skips its assertion in silence. This is where
# mutate()'s record is read, because this scope is the only one `$( )` cannot
# swallow.
if [ ! -s "$MUT_UNLANDED" ]; then
  ok "control: both mutations landed (a sed matching nothing cannot skip its assertion in silence)"
else
  bad "mutation(s) matched nothing and their assertions were SKIPPED, not failed: $(tr '\n' ' ' < "$MUT_UNLANDED")— each leaves a branch scoring as load-bearing when nothing tested it"
fi

echo
if [ "$fails" -eq 0 ]; then echo "fixture-drivability: PASS"; exit 0; fi
echo "fixture-drivability: $fails assertion(s) FAILED" >&2
exit 1
