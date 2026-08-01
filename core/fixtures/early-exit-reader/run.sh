#!/usr/bin/env bash
# early-exit-reader — a check written over a first-match reader stops firing once its
#                     input outgrows the pipe buffer, and says nothing about it.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the contract regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `grep -q` exits at its first match. Under `set -o pipefail` a pipeline's status is the
# LAST NON-ZERO one, so if the writer still had bytes to push when the reader left, the
# writer's EPIPE becomes the pipeline's answer -- and the `if` takes the branch meaning
# "not found" on input where the pattern WAS found.
#
# In a positive assertion that is a puzzling FAIL, which someone chases down. In a
# NEGATIVE one -- a match means the tree is bad -- it is a PASS, permanently, with no
# symptom. v0.207.0 found 300 such sites across 55 shipped files; 250 of them sat in a
# file that sets pipefail. I54 bans the shape. This fixture is why the ban exists: it
# demonstrates the false pass rather than asserting it.
#
# THE SECOND HALF, ADDED AT v0.231.0. I54's grammar requires the writer to be a builtin
# pushing a shell variable AND the reader to be the immediately next stage. The defect
# requires neither, so a command upstream and a variable with one filter in between both
# sit outside the ban by construction -- which is how seventeen live sites survived the
# 300-site sweep that was supposed to end this class. Assertions 5 and 6 carry the defect
# through each gap. Assertion 8 is the other direction: it proves that WITHOUT pipefail
# the identical pipeline is correct, which is what licenses I54b to exclude those files
# rather than merely hope they are safe.
#
# WHY THIS IS NOT A STOPWATCH TEST. The threshold is the pipe buffer, not a race. It was
# measured at 64 KiB on the machine this shipped from, identical idle and under 24-way
# load, so the sizes below straddle it by a wide margin rather than sitting near it.
#
# EVERY LITERAL OF THE BANNED SHAPE IS ASSEMBLED AT RUNTIME. I54's scan covers
# core/fixtures/, so a fixture spelling the shape out would be reported by the invariant
# it exists to justify.
#
# `.dist-only`: the subject is a property of bash and this repo's own idiom, not anything
# install.sh ships, so it is not a consumer's fixture to run.

set -uo pipefail

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

echo "early-exit-reader"

# --- the two checkers -----------------------------------------------------------------
# Same predicate, same pattern, same NEGATIVE polarity: a match means the input is bad and
# the checker must say so. They differ only in how the value reaches the reader.
_rd="gre""p -q"                     # assembled: see the header
_fmt="'%""s'"

write_checker() { # write_checker <path> <banned|converted>
  {
    printf '#!/usr/bin/env bash\nset -uo pipefail\nv="$(cat "$1")"\n'
    if [ "$2" = banned ]; then
      printf 'if printf %s "$v" | %s FORBIDDEN_TOKEN; then\n' "$_fmt" "$_rd"
    else
      printf 'if %s FORBIDDEN_TOKEN <<<"$v"; then\n' "$_rd"
    fi
    printf '  echo "VIOLATION"\nfi\n'
  } > "$1"
}
BANNED="$WORK/check-banned.sh"; write_checker "$BANNED" banned
CONVERTED="$WORK/check-converted.sh"; write_checker "$CONVERTED" converted
cmp -s "$BANNED" "$CONVERTED" && { echo "FIXTURE ERROR: the two checkers are byte-identical — the generator collapsed" >&2; exit 2; }
bash -n "$BANNED" && bash -n "$CONVERTED" || { echo "FIXTURE ERROR: a generated checker does not parse" >&2; exit 2; }

# --- the inputs -----------------------------------------------------------------------
# The token sits at the START in the large case: that is when the reader leaves earliest
# and the writer has the most left to push.
BIG_BAD="$WORK/big-bad";   { printf 'FORBIDDEN_TOKEN\n'; head -c 200000 /dev/zero | tr '\0' 'x'; } > "$BIG_BAD"
BIG_OK="$WORK/big-ok";     { printf 'harmless\n';        head -c 200000 /dev/zero | tr '\0' 'x'; } > "$BIG_OK"
SMALL_BAD="$WORK/small-bad"; printf 'FORBIDDEN_TOKEN\nshort\n' > "$SMALL_BAD"
[ "$(wc -c <"$BIG_BAD")" -gt 65536 ] || { echo "FIXTURE ERROR: the large input did not exceed the pipe buffer" >&2; exit 2; }

says() { bash "$1" "$2" 2>/dev/null; }

# --- Assertion 1: the converted form REPORTS the violation it is there to catch --------
# The positive outcome, asserted directly. Everything below only means something once
# this holds.
if [ "$(says "$CONVERTED" "$BIG_BAD")" = VIOLATION ]; then
  ok "converted form reports the violation in a 200 KB input (the check still fires at any size)"
else
  bad "the converted form MISSED a violation it was pointed straight at — the remedy this repo swept 300 sites to adopt does not work"
fi

# --- Assertion 2: the banned form goes SILENT on the same input ------------------------
# This is the whole point. Same predicate, same input, opposite verdict, no diagnostic.
if [ -z "$(says "$BANNED" "$BIG_BAD")" ]; then
  ok "banned form scores the SAME violating input as clean — a negative check that cannot fire, and nothing in its output says so"
else
  bad "the banned form reported the violation, so this machine does not reproduce the defect I54 bans. Either the pipe buffer grew past 200 KB or bash stopped propagating the writer's EPIPE — re-measure before trusting I54's rationale, and retire it if the shape is genuinely safe now"
fi

# --- Assertion 3 (CONTROL): silence is not just what this checker always does ----------
# Without this, assertion 2 is satisfied by a checker that never speaks.
if [ -z "$(says "$BANNED" "$BIG_OK")" ] && [ -z "$(says "$CONVERTED" "$BIG_OK")" ]; then
  ok "control: both forms are silent on a large CLEAN input (so assertion 2's silence is about the input, not the checker)"
else
  bad "a checker reported a violation in an input that contains none — the generator is wrong and assertions 1 and 2 are both meaningless"
fi

# --- Assertion 4 (CONTROL): the difference is SIZE, not the checker --------------------
# Both forms agree below the buffer. That is what makes this a trap rather than a bug
# anyone would have noticed: every small test of the banned form passes.
if [ "$(says "$BANNED" "$SMALL_BAD")" = VIOLATION ] && [ "$(says "$CONVERTED" "$SMALL_BAD")" = VIOLATION ]; then
  ok "control: both forms report the violation in a SMALL input (the banned form is not simply broken — it works until the value grows)"
else
  bad "the two forms already disagree below the pipe buffer, so the size explanation is wrong and assertion 2 is attributing the failure to the wrong cause"
fi

# --- the two shapes the ORIGINAL grammar could not see ---------------------------------
# I54's first arm requires the writer to be a BUILTIN pushing a shell variable, and the
# reader to be the IMMEDIATELY next stage. The defect needs neither. These two checkers
# carry it through the gaps, and v0.231.0 found seventeen live sites sitting in them.
write_piped() {   # a COMMAND's output, straight into the reader
  {
    printf '#!/usr/bin/env bash\nset -uo pipefail\nif cat "$1" | %s FORBIDDEN_TOKEN; then\n' "$_rd"
    printf '  echo "VIOLATION"\nfi\n'
  } > "$1"
}
write_staged() {  # a shell variable, but with ONE filter between it and the reader
  {
    printf '#!/usr/bin/env bash\nset -uo pipefail\nv="$(cat "$1")"\n'
    printf 'if printf %s "$v" | cat | %s FORBIDDEN_TOKEN; then\n' "$_fmt" "$_rd"
    printf '  echo "VIOLATION"\nfi\n'
  } > "$1"
}
write_nopf() {    # the piped form again, in a file that does NOT enable pipefail
  {
    printf '#!/usr/bin/env bash\nset -u\nif cat "$1" | %s FORBIDDEN_TOKEN; then\n' "$_rd"
    printf '  echo "VIOLATION"\nfi\n'
  } > "$1"
}
PIPED="$WORK/check-piped.sh";   write_piped  "$PIPED"
STAGED="$WORK/check-staged.sh"; write_staged "$STAGED"
NOPF="$WORK/check-nopf.sh";     write_nopf   "$NOPF"
for g in "$PIPED" "$STAGED" "$NOPF"; do
  bash -n "$g" || { echo "FIXTURE ERROR: a generated checker does not parse" >&2; exit 2; }
done
cmp -s "$PIPED" "$NOPF" && { echo "FIXTURE ERROR: the pipefail and no-pipefail checkers are byte-identical — assertion 8 would compare a file with itself" >&2; exit 2; }

# --- Assertion 5: a COMMAND upstream reaches the same false pass -----------------------
# The gap D-6c16.2 named. Nothing about the defect requires the writer to be a builtin.
if [ -z "$(says "$PIPED" "$BIG_BAD")" ]; then
  ok "a COMMAND piped into the reader scores the violating 200 KB input as clean — the same false pass, through a writer the first arm's grammar cannot see"
else
  bad "the piped-command form reported the violation, so this machine no longer reproduces the defect through a command upstream — re-measure before trusting I54b's subject set"
fi

# --- Assertion 6: ONE filter in between reaches it too ---------------------------------
# The other half of the gap, and the one no report had named: the writer here IS the
# builtin-plus-variable the first arm bans, and inserting a single stage hides it.
if [ -z "$(says "$STAGED" "$BIG_BAD")" ]; then
  ok "a variable with ONE filter between it and the reader scores the same input as clean — the first arm's own banned writer, outside its grammar because the reader is not the next stage"
else
  bad "the staged form reported the violation, so an intermediate stage no longer carries the defect — I54b's second gap would then be closed and its lines are not earning them"
fi

# --- Assertion 7 (CONTROL): both new forms are correct below the buffer -----------------
# Same control assertion 4 makes for the original pair, and it is what makes 5 and 6 a
# size trap rather than two simply-broken checkers.
if [ "$(says "$PIPED" "$SMALL_BAD")" = VIOLATION ] && [ "$(says "$STAGED" "$SMALL_BAD")" = VIOLATION ]; then
  ok "control: both new forms report the violation in a SMALL input (they work until the input grows, which is why nobody notices)"
else
  bad "a new form already disagrees below the pipe buffer, so assertions 5 and 6 are attributing their silence to size when something else is wrong"
fi

# --- Assertion 8 (CONTROL): without pipefail the SAME pipeline is correct ---------------
# This is I54b's first narrowing, asserted behaviourally rather than argued. The arm
# excludes every file that does not enable pipefail, and an exclusion that is wrong is a
# check that cannot fire over whatever it excluded.
if [ "$(says "$NOPF" "$BIG_BAD")" = VIOLATION ]; then
  ok "control: the identical pipeline in a file WITHOUT pipefail reports the violation — so I54b's pipefail narrowing excludes sites that genuinely cannot misbehave, not sites it merely hopes are safe"
else
  bad "the piped form fails even without pipefail, so I54b's first narrowing excludes a population that DOES carry the defect and the arm is blind over every file that omits the option"
fi

if [ "$fails" -eq 0 ]; then
  echo "early-exit-reader: PASS"
  exit 0
fi
echo "early-exit-reader: $fails assertion(s) FAILED"
exit 1
