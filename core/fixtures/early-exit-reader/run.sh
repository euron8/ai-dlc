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

if [ "$fails" -eq 0 ]; then
  echo "early-exit-reader: PASS"
  exit 0
fi
echo "early-exit-reader: $fails assertion(s) FAILED"
exit 1
