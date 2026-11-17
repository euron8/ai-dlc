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
# element that fired — and the honest control (V5) goes red if any element is broken
# into always-rejecting.
#
# THREE ASSERTIONS THAT ARE NOT ABOUT THE ELEMENTS, and are deliberately independent of
# them so no change to one element can flip one: the VACUITY FLOOR (a run that audits nothing
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
echo "HERMETIC-CONSUMED $AUDIT"

# IN PROCESS (BL-878). The validator is loaded ONCE (inproc_load: its column-0 guard returns after defining
# vstub_main) and every drive is inproc_run, which calls vstub_main in a subshell made to look like a fresh
# `bash <validator>`; its `exit` ends that subshell only. It runs as a program only in its cli cells (cells.decl, at
# the end).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a validator with neither its `vstub_main() {` line nor the column-0
# source guard predates the wrap and reads SKIP through fx_skip_exit (exit 0 on a consumer, never an ok; FIXTURE
# BROKEN in the distribution); exactly one half FAILs; an unreadable one is FIXTURE ERROR.
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
grep -q '^vstub_main() {$' "$AUDIT"; _wd=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$AUDIT"; _wg=$?
if [ "$_wd" -gt 1 ] || [ "$_wg" -gt 1 ]; then
  echo "FIXTURE ERROR: cannot read $AUDIT (grep exit $_wd/$_wg), so the in-process wrap cannot be judged; nothing was asserted" >&2; exit 2
fi
case "$_wd$_wg" in
  00) ;;
  11) echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  10) echo "  FAIL  $AUDIT defines \`vstub_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run vstub_main in this shell"; echo "FAIL  check-15-bypass: 1 assertion(s) wrong." >&2; exit 1 ;;
  *) echo "  FAIL  $AUDIT carries the column-0 source guard but no \`vstub_main() {\` line -- a respelled subject this fixture cannot drive"; echo "FAIL  check-15-bypass: 1 assertion(s) wrong." >&2; exit 1 ;;
esac
inproc_load "$AUDIT" || { echo "FIXTURE BROKEN: sourcing $AUDIT defined nothing" >&2; exit 2; }

# audit <path>... -> sets OUT to the validator's combined output and RC to its exit code.
# NOT a printing function called through `$( )`: a command substitution runs in a
# SUBSHELL, so an exit code assigned inside it never reaches the caller and every variant
# reads as 0 — a driver that cannot fail, in the fixture written to prove one can.
OUT=""; RC=0
audit() { OUT="$(inproc_run "$AUDIT" vstub_main --root "$TREE" "$@" 2>&1)"; RC=$?; }

# verdict <output> <tree-relative-path> -> the token `flush_expects` compares: the element a
# FINDING names, `exempt-upstream`, or `ok`. ONE parser for every arm.
verdict() {
  local out="$1" p="$2" got
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
# QUEUED, NOT RUN. The validator's cost is per PATH (about 0.7s each), and every variant used
# to be audited in its own invocation beside a copy of the honest control, so the 37 variants
# cost 74 path-audits across 37 process starts. The paths are independent of one another, so
# `flush_expects` audits the whole queue in ONE run and each queued arm reads its own
# `FINDING <path>:` / `EXEMPT <path> ` line out of that one output. The honest control is no
# longer audited beside every variant: classification reads the per-path lines, never the exit
# code, so nothing depended on a second path being in scope.
#
# CLASSIFIED ON THE VALIDATOR'S PER-PATH LINES, NEVER ON ITS EXIT CODE. Read as an exit code, a
# single exempt path yields 4 (audited nothing) and a single clean path yields 0, so a defect
# in the EXIT MAPPING alone would flip the ownership variants as well as the vacuity floor --
# three failures for one defect, which is the entanglement that makes two of the three vacuous.
# The exit mapping gets its own assertions instead.
EXP_PATH=(); EXP_WANT=(); EXP_LABEL=()
expect() {
  EXP_PATH+=("$1"); EXP_WANT+=("$2"); EXP_LABEL+=("$3")
}

flush_expects() {
  local i n="${#EXP_PATH[@]}" got want out
  # A queued path that is not a file would classify as `ok` (no line about it), which is an
  # absence passing for an audit that never happened.
  for ((i = 0; i < n; i++)); do
    [ -f "$TREE/${EXP_PATH[$i]}" ] || { echo "FAIL: queued variant '${EXP_PATH[$i]}' is not a file in the seeded tree" >&2; exit 2; }
  done
  audit "${EXP_PATH[@]}"; out="$OUT"
  # Positive conjunct: the batched run must carry the validator's own counts line for every
  # queued path, or a run that died would classify every `ok` variant as passing.
  if ! grep -qE "^validate-stub-audit: $n path\(s\) given," <<<"$out"; then
    echo "FAIL: the batched run did not report '$n path(s) given' -- every verdict below would be read off a dead run" >&2
    exit 2
  fi
  for ((i = 0; i < n; i++)); do
    want="${EXP_WANT[$i]}"; got="$(verdict "$out" "${EXP_PATH[$i]}")"
    if [ "$got" = "$want" ]; then
      case "$want" in
        ok)              note "ok" "${EXP_LABEL[$i]}" "passes all four elements" ;;
        exempt-upstream) note "ok" "${EXP_LABEL[$i]}" "dropped from scope — upstream-owned" ;;
        *)               note "ok" "${EXP_LABEL[$i]}" "rejected on $got" ;;
      esac
    else
      note "BAD" "${EXP_LABEL[$i]}" "wanted '$want', got '$got'"
      fails=$((fails + 1))
    fi
  done
}

echo "check-15-bypass: driving validate-stub-audit.sh against the seed"
echo

expect src/v1_item_absent.py    element2-item-open "V1 item-absent"
expect src/v2_reason_tbd.py     element4-reason    "V2 reason-tbd"
expect src/v3_no_file_line.sh   element3-file-line "V3 no-file-line"
expect src/v4_reason_padding.py element4-reason    "V4 reason-padding"
expect src/v6_file_no_digits.py element3-file-line "V6 file-no-digits"
expect src/v7_item_closed.py    element2-item-open "V7 item-closed"
# ELEMENT 2's STATUS TOKEN IS BOUND TO A FIELD, NOT LOOSE IN THE LINE. V7 above cites a
# CLOSED item whose title carries no `OPEN` substring, so it is green whether the token is
# bound or not — the arm read as covering this and could not fire. V35 and V36 cite CLOSED
# items whose TITLES contain the four characters, and neither is keyable by a literal token
# blacklist: V35's `reOPEN` defeats excluding the word `OPENAPI`, and V36's `the OPEN
# question` defeats a non-alphanumeric-boundary form as well, because there `OPEN` is a
# standalone word. Each refuses a wrong fix the other accepts.
expect src/v35_item_closed_reopen_title.py \
                                element2-item-open "V35 CLOSED item, 'reOPEN' in the title"
expect src/v36_item_closed_open_word_title.py \
                                element2-item-open "V36 CLOSED item, 'the OPEN question' in the title"
# THE NEAR-MISS, and it is what stops the fix from being an over-tightening. V37's title is
# V36's verbatim and its status is `(OPEN)`, so the two differ in ONE property — the status
# field, never the title. Without it every arm above is satisfied by an element 2 that
# refuses any item whose title contains `OPEN`, which refuses an honest stub whose item
# genuinely IS open. V5 is one property short of this: its title carries no `OPEN` at all.
expect src/v37_open_item_open_word_title.py \
                                ok                 "V37 OPEN item with the same 'OPEN question' title (near-miss)"
# Element 4's two floors are independent. V4 is under density only; V12 is under length
# only. Without the pair, deleting either floor leaves every variant landing on the
# other and the fixture stays green with one published floor untested.
expect src/v12_reason_short.py  element4-reason    "V12 reason-short"

# The positive control. Break any element into always-rejecting and this goes red;
# without it, all the adversaries would still be "correctly" rejected.
expect src/v5_honest.py         ok                 "V5 honest control"

# THE `Phase N` MARKER, in both directions. V13 and V16 are ABSENCE-shaped — they assert
# that nothing is reported — so a seeded near-miss alone cannot show they discriminate. V14 is their opposite number and the one
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
# disabling either half moves exactly one cell.
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

# WHETHER A `stub` INSIDE A COMMENT MEANS WHAT THE CHECK ASSUMES. V17-V22 above decide WHERE
# a prose marker is credible; these decide whether the word carries the check's subject once
# it is in a comment. V23 and V24 are the two acquittals — the consumer's negation site and
# its test-double site verbatim — and both are ABSENCE-shaped.
#
# THE SIX POSITIVE VARIANTS ARE NOT ONE ARM SIX TIMES. Each is one property short of an
# acquittal, and each is acquitted by a DIFFERENT wrong fix: V25 by a character window instead
# of strict adjacency, V26 by `skip tests/`, V27 by "the comment contains `no`", V28 by
# scanning the whole comment rather than the text before each occurrence, V29 by a
# per-comment rather than a per-occurrence test, V30 by the vocabulary half without the path
# conjunct. Each variant stands as the seed that would go red for its wrong fix.
expect src/v23_negation.ts \
                                ok                 "V23 negation denies the deferral"
expect tests/v24_test_double.py \
                                ok                 "V24 test double in a test file"
expect src/v25_neg_word_real_deferral.py \
                                element1-item-ref  "V25 'not yet' is deferral vocabulary"
expect tests/v26_test_real_deferral.py \
                                element1-item-ref  "V26 real deferral in a test file"
expect src/v27_neg_other_token.py \
                                element1-item-ref  "V27 negation qualifies another token"
expect src/v28_neg_after.sh \
                                element1-item-ref  "V28 negation after the token"
expect src/v29_two_occurrences.py \
                                element1-item-ref  "V29 second occurrence is bare"
expect src/v30_mock_prose_nontest.py \
                                element1-item-ref  "V30 mock vocabulary, non-test file"
expect src/v31_neg_deferral_word.py \
                                element1-item-ref  "V31 'not implemented stub' -- the negation word is deferral vocabulary"
expect src/v32_neg_three_words_out.py \
                                element1-item-ref  "V32 negation three words from the token, one past the bound"
expect tests/v33_mock_eleven_up.py \
                                element1-item-ref  "V33 mock vocabulary eleven lines up, one past the window"
expect tests/v34_mock_ten_up.py \
                                ok                 "V34 mock vocabulary ten lines up, the window's far edge"

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

flush_expects

# --- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome ------------------
# The three drives below are the cells: each runs the validator in process (that answer, stdout then stderr, is OUT
# and its exit RC, which the assertion after it reads) and then as a program on the same input, compared stdout,
# stderr and exit separately, byte for byte, asserting its own exit and a string it must say, so two runs that both
# printed nothing cannot read as equivalent. Outcomes: exit 4 (EXAMINED NOTHING), exit 1 (a finding), exit 0 (clean).
eq_cell() { # eq_cell <cell-id> <want rc> <must-say> <path>... -> OUT, RC from the in-process call
  local id="$1" want="$2" say="$3" e="$WORK/eq"; shift 3
  inproc_run "$AUDIT" vstub_main --root "$TREE" "$@" > "$e-$id.ip.out" 2> "$e-$id.ip.err"; echo "$?" > "$e-$id.ip.rc"
  FXCELL="$id" bash "$AUDIT" --root "$TREE" "$@" > "$e-$id.cl.out" 2> "$e-$id.cl.err"; echo "$?" > "$e-$id.cl.rc"
  OUT="$(< "$e-$id.ip.out")"$'\n'"$(< "$e-$id.ip.err")"; RC="$(< "$e-$id.ip.rc")"
  if cmp -s "$e-$id.ip.out" "$e-$id.cl.out" && cmp -s "$e-$id.ip.err" "$e-$id.cl.err" \
     && cmp -s "$e-$id.ip.rc" "$e-$id.cl.rc" && [ "$(< "$e-$id.cl.rc")" = "$want" ] \
     && grep -qF -- "$say" "$e-$id.cl.out" "$e-$id.cl.err"; then
    note "ok" "$id" "the program answers exit $want exactly as the in-process call does (stdout, stderr, exit)"
  else
    note "BAD" "$id" "in-process rc=$(< "$e-$id.ip.rc") / program rc=$(< "$e-$id.cl.rc") want $want, saying \"$say\""
    sed -n '1,3s/^/          | /p' "$e-$id.ip.out" "$e-$id.cl.out" "$e-$id.ip.err" "$e-$id.cl.err"
    fails=$((fails + 1))
  fi
}

# --- THE EXIT MAPPING, in two independent assertions. Both drive the audited-nothing
# case through a NON-HOT-PATH file rather than through an exempt one, so neither touches
# the ownership resolve and no change to the exemption can reach them.
#
# 1. A set that audits nothing must not report a pass. "Audited and found nothing" and
# "examined nothing" are the two states every vacuously-green implementation of a gate
# check has collapsed into one. The verdict token is the one declared at
# enforcement-map.yaml `empty_subject_verdict:` and bound by validate-enforcement-map.sh I93.
eq_cell cli-nothing 4 "EXAMINED NOTHING" _bmad-output/planning-artifacts/carry-over-backlog.md; out="$OUT"
case "$RC:$out" in
  4:*EXAMINED\ NOTHING*) note "ok" "vacuity floor" "a set with nothing in scope exits 4, not 0" ;;
  *) note "BAD" "vacuity floor" "a set with nothing in scope reported exit $RC without an EXAMINED NOTHING verdict"
     fails=$((fails + 1)) ;;
esac

# 2. A finding must reach the caller as a non-zero exit. The per-variant assertions above
# read the report lines and would all still pass if every exit code were 0.
eq_cell cli-finding 1 "FINDING src/v1_item_absent.py:" src/v1_item_absent.py; out="$OUT"
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
eq_cell cli-clean 0 "1 audited," _bmad-output/planning-artifacts/carry-over-backlog.md src/v5_honest.py; out="$OUT"
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
  echo "PASS  check-15-bypass: 37 variants correct against the shipping validator. Each"
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
  echo "      and the run reports what it looked at. A 'stub' inside a comment holds in both"
  echo "      directions too: a comment DENYING a deferral and one naming a test double in a"
  echo "      test file beside mock vocabulary are ignored, while six one-property-short"
  echo "      neighbours are still caught — deferral vocabulary that is not a denial, a real"
  echo "      deferral in a test file with no mock vocabulary, a negation qualifying another"
  echo "      noun, a negation after the token, a second bare occurrence, and mock prose in a"
  echo "      file that is not a test. Element 2's status token is bound to a trailing field"
  echo "      rather than loose in the line: two CLOSED items whose TITLES carry the four"
  echo "      characters OPEN are rejected -- one of them spelled so no literal token"
  echo "      blacklist can be keyed on it -- while an item with the same title and an OPEN"
  echo "      status still passes, so the binding cannot be an over-tightening."
  exit 0
fi
echo "FAIL  check-15-bypass: $fails assertion(s) wrong." >&2
exit 1
