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
audit() { OUT="$(bash "${AUDIT_BIN:-$AUDIT}" --root "$TREE" "$@" 2>&1)"; RC=$?; }
AUDIT_BIN=""

# classify <validator> <tree-relative-path> -> the same token `expect` reads, so the
# mutant section at the end scores against the SAME classifier as the arms it is proving
# load-bearing. Two classifiers would be two grammars, and the copy that cannot ship is
# the one that stays green.
classify() {
  local bin="$1" p="$2" out got
  out="$(bash "$bin" --root "$TREE" "$p" src/v5_honest.py 2>&1)"
  case "$out" in
    *"EXEMPT $p "*) got="exempt-upstream" ;;
    *"FINDING $p:"*)
      got="$(sed -nE "s@^FINDING $p:[0-9]+ ([a-z0-9-]+) .*@\1@p" <<<"$out" | head -1)"
      [ -n "$got" ] || got="rejected-without-naming-an-element" ;;
    *) got="ok" ;;
  esac
  printf '%s' "$got"
}

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

# THE `Phase N` MARKER, in both directions. V13 and V16 are ABSENCE-shaped — they assert
# that nothing is reported — so they are the arms that need the mutants in the section at
# the end of this file, not a seeded near-miss. V14 is their opposite number and the one
# that makes deleting the alternative visible; V15 sits outside the phase rule entirely
# and is what a fix applied to the WHOLE marker set breaks.
expect src/v13_phase_prose_docstring.py \
                                ok                 "V13 phase prose in a docstring"
expect src/v16_phase_section_label.py \
                                ok                 "V16 phase as a section label"
expect src/v14_phase_deferral.py \
                                element1-item-ref  "V14 phase deferral (control)"
expect src/v15_notimplemented_bare.py \
                                element1-item-ref  "V15 bare NotImplementedError"

# WHERE A PROSE MARKER IS CREDIBLE. V17 and V18 are ABSENCE-shaped and each is reachable
# by ONE half of the gate only — V17 by the comment test, V18 by the word boundary — so
# disabling either half moves exactly one cell. Both have mutants at the end of this file.
# V19 is their positive control and the arm that catches a DISARMED marker set: `\b` is
# not honoured by bash's `[[ =~ ]]` here, so `STUB_MARKER='\b(...)\b'` examines nothing at all
# and every absence-shaped arm here reads that silence as a pass.
expect src/v17_code_bare_stub.py \
                                ok                 'V17 bare stub identifier in code'
expect src/v18_comment_substring.py \
                                ok                 "V18 substring in a comment"
expect src/v20_code_todo_data.py \
                                ok                 "V20 TODO in code data"
expect src/v22_quoted_opener.sh \
                                ok                 "V22 opener inside a string literal"
expect src/v19_comment_bare_stub.py \
                                element1-item-ref  "V19 bare marker in a comment (control)"
expect src/v21_slashslash_comment.js \
                                element1-item-ref  "V21 marker in a trailing // comment"

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
# "examined nothing" are the two states every vacuously-green implementation of a gate
# check has collapsed into one. The verdict token is the one declared at
# enforcement-map.yaml `empty_subject_verdict:` and bound by validate-enforcement-map.sh I93.
audit _bmad-output/planning-artifacts/carry-over-backlog.md; out="$OUT"
case "$RC:$out" in
  4:*EXAMINED\ NOTHING*) note "ok" "vacuity floor" "a set with nothing in scope exits 4, not 0" ;;
  *) note "BAD" "vacuity floor" "a set with nothing in scope reported exit $RC without an EXAMINED NOTHING verdict"
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

# --- THE MUTANTS, and why an arm above is not enough without them.
#
# V13 and V16 are ABSENCE-shaped: they pass when the validator reports nothing about their
# file, and a validator that reported nothing about ANY file would pass them too. A seeded
# near-miss does not close that — it shows the arm discriminates between two inputs, not
# that it discriminates at all. So each of the three lines the phase rule is spelled on
# gets a mutant, and each must move exactly the arms that read it.
#
# The mutants edit COPIES under $WORK, never the installed validator, and the resolver is
# copied beside each one because the validator finds `core-paths.sh` as a SIBLING in both
# layouts (I33). A copy that cannot resolve its sibling dies at exit 2, reports no
# EXEMPT and no FINDING, and every absence-shaped arm reads that silence as a pass —
# which is why the CONTROL below is presence-shaped and runs first.
MUT="$WORK/mut"
mkdir -p "$MUT"
cp "$(dirname "$AUDIT")/core-paths.sh" "$MUT/core-paths.sh" 2>/dev/null \
  || { echo "FAIL: no core-paths.sh beside $AUDIT — every mutant would die resolving it and score a false kill" >&2; exit 2; }

cp "$AUDIT" "$MUT/control.sh"
c_pros="$(classify "$MUT/control.sh" src/v13_phase_prose_docstring.py)"
c_defr="$(classify "$MUT/control.sh" src/v14_phase_deferral.py)"
c_nie="$(classify "$MUT/control.sh" src/v15_notimplemented_bare.py)"
if [ "$c_defr" = "element1-item-ref" ] && [ "$c_nie" = "element1-item-ref" ] && [ "$c_pros" = "ok" ]; then
  note "ok" "mutant control" "an unmutated copy reports V14 and V15 and stays quiet on V13"
else
  note "BAD" "mutant control" "an unmutated copy answered V13='$c_pros' V14='$c_defr' V15='$c_nie' — the mutants below would be scoring the harness"
  fails=$((fails + 1))
fi

# name | sed program | probe | the token the mutant must produce
#
# EACH SED IS ANCHORED ON THE LINE THAT DEFINES ONE RULE, never on text two rules share.
# The `cmp -s` guard below turns a sed that stopped matching into a loud BAD rather than a
# silent survival, which is what happened to the first two of these when the marker set
# split: both were keyed on a `STUB_MARKER=` line that no longer exists.
MUT_NAME=(
  phase-alternative-restored phase-marker-dropped absence-widened
  notimplementederror-dropped prose-marker-unbounded prose-gate-on-raw-line
  comment-openers-emptied quote-guard-dropped
)
MUT_SED=(
  "s@^CODE_MARKER='.*'\$@CODE_MARKER='(NotImplementedError|Phase [0-9])'@"
  "s@^PHASE_MARKER='Phase \[0-9\]'\$@PHASE_MARKER='PhaseThatCannotOccur [0-9]'@"
  "s@^PHASE_ABSENCE='.*'\$@PHASE_ABSENCE='.'@"
  "s@^CODE_MARKER='.*'\$@CODE_MARKER='NotImplementedErrorThatCannotOccur'@"
  "s@^PROSE_MARKER='.*'\$@PROSE_MARKER='(stub|TODO|FIXME|wired later)'@"
  's@^      if ! { \[ -n "\$ctext" \] && \[\[ \$ctext =~ \$PROSE_MARKER \]\]; }; then$@      if ! [[ $line =~ $PROSE_MARKER ]]; then@'
  "s@^COMMENT_OPENERS='.*'\$@COMMENT_OPENERS='#'@"
  's@^    case "[$]pre" in .*$@    :@'
)
MUT_PROBE=(
  src/v13_phase_prose_docstring.py src/v14_phase_deferral.py src/v16_phase_section_label.py
  src/v15_notimplemented_bare.py src/v18_comment_substring.py src/v17_code_bare_stub.py
  src/v21_slashslash_comment.js src/v22_quoted_opener.sh
)
MUT_WANT=(
  element1-item-ref ok element1-item-ref
  ok element1-item-ref element1-item-ref
  ok element1-item-ref
)
MUT_WHY=(
  "V13 — the sprint-306 docstring is a finding again the moment the alternative is matched on the raw line"
  "V14 — a real phase deferral goes unexamined the moment the alternative is deleted outright"
  "V16 — a section label is a finding again the moment the absence vocabulary matches anything"
  "V15 — a marker OUTSIDE the phase rule goes unexamined, which no other arm here notices"
  "V18 — a substring inside an identifier is a finding again without the word boundary"
  "V17 — a variable named 'stub' is a finding again the moment the marker is read off the raw line"
  "V21 — a // comment stops being read the moment the opener set is narrowed to #"
  "V22 — an opener inside a string literal becomes a comment the moment the quote guard goes"
)

for i in 0 1 2 3 4 5 6 7; do
  label="${MUT_NAME[$i]}"; copy="$MUT/$label.sh"
  sed "${MUT_SED[$i]}" "$AUDIT" > "$copy" 2>/dev/null
  # `cmp -s` first: a sed that matched nothing produces an unmutated copy, which answers
  # the baseline on every probe and scores a survival that reads as a working arm.
  if cmp -s "$AUDIT" "$copy"; then
    note "BAD" "MUTANT $label" "the sed matched nothing — no mutation applied, so nothing was proven"
    fails=$((fails + 1)); continue
  fi
  got="$(classify "$copy" "${MUT_PROBE[$i]}")"
  if [ "$got" = "${MUT_WANT[$i]}" ]; then
    note "ok" "MUTANT $label" "killed by ${MUT_WHY[$i]}"
  else
    note "BAD" "MUTANT $label" "SURVIVED — ${MUT_PROBE[$i]} answered '$got', wanted '${MUT_WANT[$i]}'"
    fails=$((fails + 1))
  fi
done

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  check-15-bypass: 22 variants correct against the shipping validator. Each"
  echo "      adversary is rejected on its intended element — absent item, CLOSED item, no"
  echo "      file:line, digitless file ref, and element 4's two floors separately (a"
  echo "      padded reason under density, a short reason under length) — the honest stub"
  echo "      satisfies all four, and both ownership pairs discriminate: the upstream-owned"
  echo "      file and the core fixture are dropped from scope while their consumer-owned"
  echo "      neighbours at adjacent paths are still audited. The phase marker holds in"
  echo "      both directions: prose in a docstring and prose as a section label are"
  echo "      ignored, a real deferral written only as a phase reference is still caught,"
  echo "      and a bare NotImplementedError is examined without any prose beside it. The"
  echo "      prose markers hold in both directions too, and each half of that gate has a"
  echo "      variant the other half cannot reach: a bare 'stub' identifier in code and a"
  echo "      TODO in a data literal are ignored, a substring inside an identifier is"
  echo "      ignored even inside a comment, an opener inside a string literal is not a"
  echo "      comment, while a bare marker in a leading comment and one in a trailing //"
  echo "      comment are both still caught. The three non-element assertions hold too:"
  echo "      the exit mapping separates audited-nothing from clean and from a finding,"
  echo "      and the run reports what it looked at. Eight mutants prove the phase rule's"
  echo "      three lines and the prose gate's four load-bearing."
  exit 0
fi
echo "FAIL  check-15-bypass: $fails assertion(s) wrong." >&2
exit 1
