#!/usr/bin/env bash
# Drive the check-15-bypass fixture (Check 16 — stub audit) and assert, for each seeded
# variant, WHICH element rejects it. Exit 0 = each adversary fails on its intended
# element and the honest control passes all four.
#
# WHAT THIS DRIVES, AND WHAT CHANGED. This ran against a RESTATEMENT for its whole life:
# Check 16 carried `enforcer: []`, so there was no validator to call and this driver
# re-implemented the check's published element regexes inline. Its own header said what
# that was worth — "It proves the FIXTURE's claim, not the ADJUDICATOR's behaviour." A
# grammar spelled twice drifts, and the copy that cannot ship is the one that stays
# green. `scripts/ai-dlc/validate-stub-audit.sh` is now the elements' single home and
# this driver calls it, so the code under test and the code that ships are the same
# bytes. The limit that remains is narrower and unavoidable: an adjudicator that
# ignores the script's verdict is still not detectable from a script.
#
# WHY ASSERT THE ELEMENT AND NOT THE VERDICT. All the adversaries would be "rejected" by
# a check that rejected everything. Asserting only pass/fail passes on that bug. Each
# adversary here is built to satisfy every element but one, so the driver can name the
# element that fired — and the honest control (V5) is the mutant-detector that goes red
# if any element is broken into always-rejecting.
#
# THREE ASSERTIONS THAT ARE NOT ABOUT THE ELEMENTS, and are deliberately independent of
# them so no element mutation can flip one: the VACUITY FLOOR (a run that audits nothing
# must not report a pass), the FINDING EXIT (a rejection must reach the caller as a
# non-zero status), and the COUNTS (a verdict that does not say what it looked at cannot
# be told apart from one that looked at nothing). All three are what a script inherits
# from the agent it replaces.
#
# Usage: run.sh

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TREE="$(bash "$HERE/seed.sh" "$WORK")"
BACKLOG="$TREE/_bmad-output/planning-artifacts/carry-over-backlog.md"
[ -f "$BACKLOG" ] || { echo "FAIL: seed did not produce a backlog at '$BACKLOG'" >&2; exit 2; }

fails=0
note() { printf '  %-6s %-30s %s\n' "$1" "$2" "$3"; }

# Resolve the validator by walking UP from THIS FILE for either layout, naming both
# rather than counting `..`: the fixture runs from the distribution (`core/scripts/`)
# and from a consumer (`scripts/ai-dlc/`), and rooting the chain anywhere but its own
# self-location is the parent-sharing the install mapping breaks (I33).
AUDIT=""
d="$HERE"
while [ "$d" != "/" ]; do
  if [ -x "$d/core/scripts/validate-stub-audit.sh" ]; then AUDIT="$d/core/scripts/validate-stub-audit.sh"; break
  elif [ -x "$d/scripts/ai-dlc/validate-stub-audit.sh" ]; then AUDIT="$d/scripts/ai-dlc/validate-stub-audit.sh"; break; fi
  d="$(dirname "$d")"
done

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. The validator reaches a consumer on the pull
# that carries this file and may land later in the same pull. "Validator not installed" is
# NOT "check broken", and treating it as a hard error deadlocks the reference consumer:
# ai-dlc-update's self-update requires its derived fixtures green, so failing here blocks
# the very cycle that installs the validator.
#
# In the DISTRIBUTION it is always present, so its absence stays a hard exit 2 and upstream
# can never go green without running the real thing. Only a consumer skips.
IS_DIST=0; [ -d "$HERE/../../../core/skills/ai-dlc" ] && IS_DIST=1
if [ -z "$AUDIT" ]; then
  if [ "$IS_DIST" = 1 ]; then
    echo "FAIL: no validate-stub-audit.sh found walking up from $HERE — in the distribution the check MUST be evaluable, and passing without it would report the elements as working when they were never run." >&2
    exit 2
  fi
  echo "SKIP  check-15-bypass: validate-stub-audit.sh is not installed in this consumer yet;"
  echo "      it lands with this same pull. Nothing was asserted."
  exit 0
fi

# audit <path>... -> sets OUT to the validator's combined output and RC to its exit code.
# NOT a printing function called through `$( )`: a command substitution runs in a
# SUBSHELL, so an exit code assigned inside it never reaches the caller and every variant
# reads as 0 — a driver that cannot fail, in the fixture written to prove one can.
OUT=""; RC=0
audit() { OUT="$(bash "$AUDIT" --root "$TREE" "$@" 2>&1)"; RC=$?; }

# expect <tree-relative-path> <want-element-token|ok|exempt-upstream> <label>
#
# CLASSIFIED ON THE VALIDATOR'S PER-PATH LINES, NEVER ON ITS EXIT CODE, and each variant
# is audited alongside the honest control so the run always has something in scope. Both
# choices exist to keep these assertions independent of the three below: read as an exit
# code, a single exempt path yields 4 (audited nothing) and a single clean path yields 0,
# so a mutation to the EXIT MAPPING alone would flip the ownership variants as well as
# the vacuity floor — three failures for one defect, which is the entanglement that makes
# two of the three vacuous. The exit mapping gets its own assertions instead.
expect() {
  local want="$2" out got
  audit "$1" src/v5_honest.py; out="$OUT"
  case "$out" in
    *"EXEMPT $1 "*) got="exempt-upstream" ;;
    *"FINDING $1:"*)
      got="$(sed -nE "s@^FINDING $1:[0-9]+ ([a-z0-9-]+) .*@\1@p" <<<"$out" | head -1)"
      [ -n "$got" ] || got="rejected-without-naming-an-element" ;;
    *) got="ok" ;;
  esac
  if [ "$got" = "$want" ]; then
    case "$want" in
      ok)              note "ok" "$3" "passes all four elements" ;;
      exempt-upstream) note "ok" "$3" "dropped from scope — upstream-owned" ;;
      *)               note "ok" "$3" "rejected on $got" ;;
    esac
  else
    note "BAD" "$3" "wanted '$want', got '$got'"
    fails=$((fails + 1))
  fi
}

echo "check-15-bypass: driving validate-stub-audit.sh against the seed"
echo

expect src/v1_item_absent.py    element2-item-open "V1 item-absent"
expect src/v2_reason_tbd.py     element4-reason    "V2 reason-tbd"
expect src/v3_no_file_line.sh   element3-file-line "V3 no-file-line"
expect src/v4_reason_padding.py element4-reason    "V4 reason-padding"
expect src/v6_file_no_digits.py element3-file-line "V6 file-no-digits"
expect src/v7_item_closed.py    element2-item-open "V7 item-closed"
# Element 4's two floors are independent. V4 is under density only; V12 is under length
# only. Without the pair, deleting either floor leaves every variant landing on the
# other and the fixture stays green with one published floor untested.
expect src/v12_reason_short.py  element4-reason    "V12 reason-short"

# The positive control. Break any element into always-rejecting and this goes red;
# without it, all the adversaries would still be "correctly" rejected.
expect src/v5_honest.py         ok                 "V5 honest control"

# The exemption pair. V8 satisfies zero elements and must NEVER reach the elements
# at all; V9 satisfies zero elements at a core-ADJACENT path and must reach them.
# Drop the exemption and V8 flips to element1-item-ref. Widen it to all of
# `.claude/` and V9 flips to exempt-upstream — a consumer stub going unaudited.
expect .claude/skills/ai-dlc-update/reconcile/apply.sh \
                                exempt-upstream    "V8 upstream-owned"
expect .claude/hooks/my-own-hook.sh \
                                element1-item-ref  "V9 consumer hook (control)"

# The FIXTURE-ownership pair, the same shape one directory over. tests/fixtures/ is
# SHARED: core ships its self-tests there and the consumer's own sit beside them. Drop
# the fixtures/ arm from to_consumer_glob() and V10 flips to element1-item-ref — a core
# fixture audited as consumer-authored, whose only remediation VACATES it, because those
# markers are what its own assertions read. Collapse the entries to a bare
# tests/fixtures/* and V11 flips to exempt-upstream — a consumer's own unaudited stub
# riding out on our exemption.
expect tests/fixtures/check-15-bypass/seed.sh \
                                exempt-upstream    "V10 core fixture"
expect tests/fixtures/check-15-bypass-local/seed.sh \
                                element1-item-ref  "V11 consumer fixture (control)"

# --- THE EXIT MAPPING, in two independent assertions. Both drive the audited-nothing
# case through a NON-HOT-PATH file rather than through an exempt one, so neither touches
# the ownership resolve and no exemption mutation can reach them.
#
# 1. A set that audits nothing must not report a pass. "Audited and found nothing" and
# "audited nothing" are the two states every vacuously-green implementation of a gate
# check has collapsed into one.
audit _bmad-output/planning-artifacts/carry-over-backlog.md; out="$OUT"
case "$RC:$out" in
  4:*AUDITED\ NOTHING*) note "ok" "vacuity floor" "a set with nothing in scope exits 4, not 0" ;;
  *) note "BAD" "vacuity floor" "a set with nothing in scope reported exit $RC without an AUDITED NOTHING verdict"
     fails=$((fails + 1)) ;;
esac

# 2. A finding must reach the caller as a non-zero exit. The per-variant assertions above
# read the report lines and would all still pass if every exit code were 0.
audit src/v1_item_absent.py; out="$OUT"
if [ "$RC" -eq 1 ]; then
  note "ok" "finding exits 1" "a rejected file exits 1"
else
  note "BAD" "finding exits 1" "a rejected file exited $RC"
  fails=$((fails + 1))
fi

# --- THE COUNTS. Independent of the elements (it asserts what the run LOOKED AT, never
# what it found) and of the exemption (neither path is core, so the dropped count is 0
# either way). A verdict with no counts cannot be told apart from one that compared
# nothing, which is the whole reason this check stopped being a paragraph.
audit _bmad-output/planning-artifacts/carry-over-backlog.md src/v5_honest.py; out="$OUT"
# Here-string, never a pipe: `grep -q` stops at its first match and a builtin still
# pushing bytes takes EPIPE, so under pipefail the branch inverts on large input (I54).
if grep -qE '^validate-stub-audit: 2 path\(s\) given, 1 hot-path, [0-9]+ dropped upstream-owned, [0-9]+ resolver-undetermined \(in scope\), 1 audited,' <<<"$out"; then
  note "ok" "counts reported" "2 given / 1 hot-path / 1 audited"
else
  note "BAD" "counts reported" "the counts line did not report 2 given, 1 hot-path, 1 audited"
  fails=$((fails + 1))
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  check-15-bypass: 12 variants correct against the shipping validator. Each"
  echo "      adversary is rejected on its intended element — absent item, CLOSED item, no"
  echo "      file:line, digitless file ref, and element 4's two floors separately (a"
  echo "      padded reason under density, a short reason under length) — the honest stub"
  echo "      satisfies all four, and both ownership pairs discriminate: the upstream-owned"
  echo "      file and the core fixture are dropped from scope while their consumer-owned"
  echo "      neighbours at adjacent paths are still audited. The three non-element"
  echo "      assertions hold too: the exit mapping separates audited-nothing from clean"
  echo "      and from a finding, and the run reports what it looked at."
  exit 0
fi
echo "FAIL  check-15-bypass: $fails assertion(s) wrong." >&2
exit 1
