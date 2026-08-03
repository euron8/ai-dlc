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

echo
if [ "$fails" -eq 0 ]; then echo "mutation-red-replay: PASS"; exit 0; fi
echo "mutation-red-replay: $fails assertion(s) FAILED" >&2
exit 1
