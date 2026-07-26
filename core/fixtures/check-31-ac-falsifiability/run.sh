#!/usr/bin/env bash
# Exercise validate-ac-falsifiability.sh (gate-validation Check 31).
#
# Exit 0 iff:
#   - bad-unbounded.md      FAILS (1)  -- a forbidden term on the AC header line
#   - bad-continuation.md   FAILS (1)  -- forbidden term on a CONTINUATION line;
#                                         a line-scoped check misses this one
#   - dangling-evidence.md  FAILS (1)  -- prior_evidence path not on disk
#   - dangling-anchor.md    FAILS (1)  -- path resolves, anchor absent
#   - good-bounded.md       PASSES (0) -- OVER-FIRE CONTROL. An AC entirely about
#                                         covering a set, correctly bounded, using
#                                         no forbidden term. Proves the check
#                                         discriminates on the word, not the topic.
#   - good-evidence.md      PASSES (0) -- OVER-FIRE CONTROL, resolvable citation
#   - waiver.md             PASSES (0) -- waiver path reachable, AND the waiver is
#                                         REPORTED on stdout (suppresses the FAIL,
#                                         never the report)
#   - undeclared-form.md    DISARMS (2) -- declares ACs, presents none in the form
#                                          stories-test-strategy.md mandates. Must
#                                          NOT exit 0: an AC the checker cannot read
#                                          is not an AC that passed.
#   - an empty term list    DISARMS (2) -- FAIL-CLOSED control. A zero-term lexicon
#                                          reports every story clean and prints the
#                                          same shape of line as a real pass.
#   - two MUTATION controls hold        -- neuter the term check and the
#                                          prior_evidence check independently; each
#                                          must turn its own red case green. Two
#                                          guards need two mutants; one mutant
#                                          licenses only one FAIL.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

V=""
for cand in \
  "$DIR/../../scripts/validate-ac-falsifiability.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-ac-falsifiability.sh" \
  "$DIR/../../core/scripts/validate-ac-falsifiability.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-ac-falsifiability.sh" >&2; exit 2; }

# The lexicon lives in the step file, not in the validator. Resolve it explicitly so
# the fixture drives the same list the pipeline does.
LEX=""
for cand in \
  "$DIR/../../skills/ai-dlc/steps/stories-test-strategy.md" \
  "$DIR/../../../.claude/skills/ai-dlc/steps/stories-test-strategy.md" \
  "$DIR/../../core/skills/ai-dlc/steps/stories-test-strategy.md"; do
  [ -f "$cand" ] && LEX="$cand" && break
done
[ -n "$LEX" ] || { echo "run.sh: could not locate stories-test-strategy.md (the lexicon home)" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-31.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }

echo "check-31-ac-falsifiability:"

# Never `out=$(...)` for the verdict: command substitution moves the validator's
# status into the assignment's, and a fixture that reads the wrong status proves
# nothing. Run it, then read $?.
expect() { # <expected-rc> <payload> <label>
  ( cd "$DIR" && bash "$V" --lexicon-from "$LEX" "$DIR/$2" ) >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$1" ]; then ok "$3"; else bad "$3 (expected rc=$1, got rc=$got)"; fi
}

expect 1 bad-unbounded.md     "a forbidden term on the AC header is rejected"
expect 1 bad-continuation.md  "a forbidden term on a CONTINUATION line is rejected (block scope, not line scope)"
expect 1 dangling-evidence.md "an unresolvable prior_evidence path is rejected"
expect 1 dangling-anchor.md   "a resolvable path with an absent anchor is rejected"
expect 0 good-bounded.md      "OVER-FIRE CONTROL: a correctly-bounded set-covering AC passes"
expect 0 good-evidence.md     "OVER-FIRE CONTROL: a resolvable prior_evidence citation passes"
expect 0 waiver.md            "a declared falsifiability_waiver suppresses the FAIL"
expect 2 undeclared-form.md   "a story declaring ACs in an undeclared form DISARMS (never exits 0)"

# The waiver must still be REPORTED. A waiver that silences the report is a hole
# nobody can audit.
if ( cd "$DIR" && bash "$V" --lexicon-from "$LEX" "$DIR/waiver.md" ) 2>/dev/null | grep -q 'waiver'; then
  ok "the waiver is printed, not silently honoured"
else
  bad "waiver.md passed but printed no waiver line — a suppressed FAIL with no record"
fi

# --- FAIL-CLOSED control ------------------------------------------------------
# An empty lexicon must not be able to report a clean scan.
printf '<!-- AC_UNBOUNDED_TERMS v1 -->\n<!-- AC_UNBOUNDED_TERMS_END -->\n' > "$WORK/empty-lex.md"
( cd "$DIR" && bash "$V" --lexicon-from "$WORK/empty-lex.md" "$DIR/bad-unbounded.md" ) >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "FAIL-CLOSED: a zero-term lexicon exits 2, not 0"
else
  bad "a zero-term lexicon did not exit 2 — the check can be disarmed into a silent pass"
fi
( cd "$DIR" && bash "$V" --lexicon-from "$WORK/no-such-file.md" "$DIR/bad-unbounded.md" ) >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "FAIL-CLOSED: an unreadable lexicon exits 2, not 0"
else
  bad "an unreadable lexicon did not exit 2"
fi

# --- MUTATION controls -------------------------------------------------------
# Build each mutant as a COPY and assert `cmp -s` that the edit matched something.
# A sed that matches nothing yields a mutant identical to the subject, which then
# "fails as expected" for the wrong reason — a vacuous proof.
mutate() { # <name> <sed-expr> <payload> <label>
  local m="$WORK/$1.sh"
  cp "$V" "$m"
  sed -i.bak "$2" "$m" 2>/dev/null || sed -i '' "$2" "$m" 2>/dev/null
  rm -f "$m.bak"
  if cmp -s "$V" "$m"; then
    bad "FIXTURE ERROR: mutation '$1' matched nothing — the assertion below would prove nothing"
    return
  fi
  ( cd "$DIR" && bash "$m" --lexicon-from "$LEX" "$DIR/$3" ) >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ok "$4"
  else
    bad "$4 — the mutant still rejected it, so the guard under test is not what produced the FAIL"
  fi
}

mutate term-off 's/if printf .%s\\n. "\$body" | grep -qiE "(\^|\[\^\[:alnum:\]_\])\${term}(\[\^\[:alnum:\]_\]|\\\$)"; then/if false; then/' \
  bad-unbounded.md "MUTATION: neutering the term check turns bad-unbounded green (the term ban is what fails it)"

# Neuter the EXISTENCE TEST, not the loop that drives it. Emptying the candidate
# list leaves `resolved` unset, which is the same state a real miss produces, so
# the mutant fails for the guard's own reason and demonstrates nothing. The guard
# is `[ -f ... ]`; that is what has to go.
mutate evidence-off 's/\[ -f "\$base\/\$cpath" \] \&\&/true \&\&/' \
  dangling-evidence.md "MUTATION: neutering the -f existence test turns dangling-evidence green (that test is what fails it)"

echo
if [ "$rc" -eq 0 ]; then
  echo "check-31-ac-falsifiability: PASS"
else
  echo "check-31-ac-falsifiability: FAILED" >&2
fi
exit $rc
