#!/usr/bin/env bash
# derived-fence-binding — assert invariant I108 both fires and discriminates.
# Also hosts I75's seeded-drift oracle (A16-A19), which had no fixture anywhere, and I121's
# battery (A20-A33): the verify-shape paragraph every role contract carries, with its three
# wrong arms (opener-only compare, hand-listed population, substring key) each scored killed.
# And I122's battery (A34-A47): the advisor paragraph directly below it in every role contract,
# the same three wrong arms, and a cross-probe that neither arm is satisfied by the other's text.
# And A48-A50: the three-way drop matrix over I121, I122 and I123's chunked-write paragraph below
# them, where the advisor drop must leave I123 reporting MISPLACED rather than green.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = one regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH. Seven files under core/team-roles/ teach an agent how to
# write a derivation the machine can check, and none of them owns the grammar they teach:
# core/scripts/validate-artifact-derivations.sh decides what opens a block. A taught form that
# reader cannot open makes it print zero derivations and exit 0 — no check and no error — so a
# drift in the taught text is invisible in exactly the direction that matters. I108 binds the
# five prose copies to each other, forbids a sixth, and runs the reader over every role file
# that teaches the passage or templates a derivation record field.
#
# WHY BOTH DIRECTIONS ARE SEEDED, AND WHY THE WRONG FIXES ARE SEEDED TOO. Every one of I108's
# three halves is absence-shaped: an extractor that stops matching compares empty to empty, a
# site scan that stops matching finds no sixth copy, and a population scan that stops matching
# leaves nothing to ask the reader about. All three silences read exactly like a conforming
# tree. So the battery seeds an offender for each half, and it also builds the three arms this
# arm could plausibly have been written as and scores them on the tree that separates them —
# a receipt that accepts two implementations has established neither.
#
# W3 IS NOT HYPOTHETICAL. It is the shape this arm was first written as: half C's population
# keyed on files carrying a fence opener, which structurally excludes from the population the
# one file the arm exists to catch — rename a template's info string and the file stops
# matching the key, leaves the population, and the arm reports a clean tree. Measured against
# that first cut with remediator.md's opener renamed: zero findings, exit 0. A05 and W3 below
# are that measurement, made permanent.
#
# EVERY MUTATION IS A COPY GUARDED BY `cmp -s`. A mutation whose pattern stopped matching
# leaves a tree that is not a mutant, and the assertion built on it would test a clean tree
# while printing the same line. A mutation that does not apply is reported as FIXTURE BROKEN,
# never scored.
#
# THE CONTROL IS NECESSARY AND NOT SUFFICIENT. Assertion 0 requires the unmutated seed to pass
# AND requires the validator's own OK line to be PRESENT, because a subject replaced by
# `exit 0` also passes with nothing reported. Every assertion below is presence-shaped for the
# same reason: each demands a specific message, so a validator that emits nothing fails them by
# construction rather than passing them by silence.
set -uo pipefail
# The I75 arms edit a root block naming AI_DLC_PROJECT_ROOT; an ambient value would steer the
# validator's own root resolution, so the environment is cleared (I87).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"

# Distribution-only. validate-enforcement-map.sh is not shipped, so on a consumer there is
# nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$D_ROOT/scripts/validate-enforcement-map.sh" ]; then
  echo "derived-fence-binding: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  exit 0
fi

PRISTINE="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$PRISTINE" "$WORK"' EXIT

fails=0
asserted=0
ok()  { printf '  ok    %s\n' "$1"; asserted=$((asserted + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); asserted=$((asserted + 1)); }

ARM="scripts/validate-enforcement-map.sh"
READER="core/scripts/validate-artifact-derivations.sh"
OKLINE="OK: enforcement-map.yaml in sync with gate-validation.md"

# fresh — a fresh COPY of the pristine seed, never an edit of it. A mutation applied in place
# leaks into every later assertion, and the one that leaks reads as the one that fired.
fresh() {
  rm -rf "$WORK/t"
  cp -R "$PRISTINE" "$WORK/t"
  printf '%s' "$WORK/t"
}

# edit <tree> <relative file> <awk program> — rewrite through awk, then REQUIRE the bytes to
# have changed. Returns non-zero and reports FIXTURE BROKEN when the program matched nothing.
edit() {
  local t="$1" rel="$2" prog="$3" f
  f="$t/$rel"
  if [ ! -f "$f" ]; then
    bad "FIXTURE BROKEN — $rel is not in the seed, so the mutation below has no subject"
    return 1
  fi
  awk "$prog" "$f" > "$f.mut" || { bad "FIXTURE BROKEN — awk failed on $rel"; rm -f "$f.mut"; return 1; }
  if cmp -s "$f" "$f.mut"; then
    bad "FIXTURE BROKEN — the mutation of $rel changed nothing; the assertion below would test a clean tree"
    rm -f "$f.mut"; return 1
  fi
  mv "$f.mut" "$f"
}

# run_arm <tree> <arm> — run ONLY that arm's unit in that tree and print its combined output. A
# selected run costs the validator's prologue plus one arm instead of every invariant scanning a
# tree this fixture does not care about. THE ARM IS REQUIRED, with no default: this fixture
# hosts I108 and I121, and a default would let a caller written for one silently test the
# other. A missing arm exits 2, which guard_sel reports as FIXTURE BROKEN.
run_arm() {
  [ -n "${2:-}" ] || { echo "run_arm called with no arm"; return 2; }
  bash "$1/$ARM" --arms "$2" 2>&1
}

# guard_sel <rc> <output> — a validator exit of 2 is a SELECTION or generated-subprogram
# failure and never an invariant violation. Nothing was checked, so it must not be scored as a
# mutant surviving OR as one dying; the second reading is the dangerous one because it prints
# ok.
guard_sel() {
  [ "$1" = "2" ] || return 0
  bad "FIXTURE BROKEN — 'validate-enforcement-map.sh --arms' exited 2. That is a selection or usage failure, so NOTHING was checked here. The validator said: $2"
  return 1
}

# says <arm> <label> <tree> <expected substring> — the arm must REPORT it.
says() {
  local arm="$1" label="$2" t="$3" want="$4" out rc
  out="$(run_arm "$t" "$arm")"; rc=$?
  guard_sel "$rc" "$out" || return 0
  case "$out" in
    *"$want"*) ok "$label" ;;
    *)         bad "$label — the arm did NOT report it (rc=$rc). The predicate no longer reaches this subject, and a corpus it cannot see reads exactly like a corpus with nothing wrong in it." ;;
  esac
}

# EVERY WRONG FIX IS SCORED THE SAME WAY, INLINE, AND ON THREE OUTCOMES RATHER THAN TWO. It is
# not enough that the wrong fix stops printing the finding: an absence is also what a run that
# died produces, and scoring that as a kill is how a battery certifies silence. So each of the
# three below branches on the finding STILL BEING PRESENT (the tree does not separate the two
# implementations, and the assertion above it is not evidence about either), on the specific
# message that identifies WHICH mechanism killed it, and on anything else. Measured while
# writing them: all three wrong fixes are killed by I108's own probe or by a different half of
# it, never by the corpus arm they disable — which is exactly why the mechanism that kills is
# named in the assertion rather than left as "it went red".

# --- The mutation programs, one place each ------------------------------------
#
# Each is anchored on a line that occurs exactly ONCE in the file it edits, and `edit` above
# refuses a program that matches nothing.

# A word inside the taught passage's BODY, not its opening line. An arm comparing only the
# opener would not see this, which is exactly what W1 below is built to demonstrate.
MUT_DRIFT='
{ if ($0 == "prefix and no more, so output the command itself printed with leading spaces keeps them.") {
    print "prefix and no more, so output the command itself printed with leading blanks keeps them."; next }
  print }'

# The passage`s CLOSING delimiter, reworded. The extractor must go empty and say so rather than
# running to end of file and reporting five intact copies as a fork.
MUT_CLOSE='
{ if ($0 == "in the sentence beside the block.") { print "in the sentence next to the block."; next }
  print }'

# The taught fence`s info string given a trailing word: still a fence to a human, opened by
# nothing.
MUT_INFO='
{ if ($0 == "```derived") { print "```derived block"; next } print }'

# The record template`s info string renamed to a word the reader does not accept. This is the
# shape whose file leaves a fence-keyed population.
MUT_TEMPLATE='
{ if ($0 == "```derived") { print "```derivation"; next } print }'

# READER MUTANT: indent-blind, which is the shape this reader had before it learned that a
# fence inside a list item is still a fence. The taught passage now states the indent rule, so
# the arm`s probe must notice when the reader stops honouring it.
MUT_READER_FLAT='
{ if ($0 ~ /if is_opener "\$\{line#"\$indent"\}"; then/) { sub(/"\$\{line#"\$indent"\}"/, "\"$line\"") } print }'

# READER MUTANT: the info-string arm widened back to a prefix match, which opens a phantom
# block on any wrapped sentence beginning with the token.
MUT_READER_WIDE='
{ if ($0 ~ /\[ "\$b" = .```derived. \]/) { print "  case \"$b\" in \x27```derived\x27*) return 0;; esac; return 1"; next } print }'

# WRONG FIX W1: the passage extractor keeps only its FIRST line, so half A compares openers.
MUT_W1='
{ if ($0 == "    on { buf = buf $0 \"\\n\" }") { print "    on \&\& buf == \"\" { buf = buf $0 \"\\n\" }"; next } print }'

# WRONG FIX W2: i108_declared binds four of the five, with one name written twice so the
# assignment stays well formed.
MUT_W2='
{ if ($0 == "core/team-roles/tea.md\x27") { print "core/team-roles/analyst.md\x27"; next } print }'

# WRONG FIX W3: half C`s population keyed on the fence opener — the token that drifts — instead
# of on the record field, which does not.
MUT_W3='
{ if ($0 ~ /grep -rlE .\^\[\[:blank:\]\]\*- derivation:./) {
    print "                grep -rlF -- \x27```derived\x27 \"$1\" 2>/dev/null; } | LC_ALL=C sort -u; }"; next }
  print }'

# THE TAUGHT FENCE INDENTED IN ONE COPY ONLY: a fork in LEADING BLANKS and nothing else. The
# reader still opens an indented fence, so half C is silent here by construction and no channel
# but half A's byte comparison can see it. It is seeded because nothing else seeds whitespace --
# every other case in this file changes a WORD -- and W4 below is the wrong fix it exists to
# kill.
MUT_INDENT='
{ if ($0 == "```derived") { print "  ```derived"; next }
  if ($0 == "$ grep -c \x27save_state_fn\x27 rebalancer/execution.py") { print "  $ grep -c \x27save_state_fn\x27 rebalancer/execution.py"; next }
  if ($0 == "19") { print "  19"; next }
  if ($0 == "```" && !closed) { print "  ```"; closed = 1; next }
  print }'

# A SECOND command/output pair whose CLOSING fence is indented deeper than its opener. A closer
# indented deeper is not a closer, so the block runs to end of file: the reader reports GRAMMAR
# on STDERR while stdout still carries a row for the file, and --list exits 0 either way.
# Applied to all five so half A stays quiet and only half C's stderr channel can see it.
MUT_UNCLOSED='
{ if ($0 == "19") { print "19"; print "$ echo two"; print "two"; next }
  if ($0 == "```" && opened && !closed) { print "  ```"; closed = 1; next }
  if ($0 == "```derived") { opened = 1 }
  print }'

# WRONG FIX W4: leading blanks normalised at the comparison site, so two copies differing only
# in the indent of their fence compare equal.
MUT_W4='
{ if ($0 == "    i108_got=\"$(i108_passage \"$REPO_ROOT/$i108_rel\")\"") {
    print "    i108_got=\"$(i108_passage \"$REPO_ROOT/$i108_rel\" | sed \x27s/^[[:blank:]]*//\x27)\""; next }
  print }'

# WRONG FIX W5: the reader`s two streams merged. The GRAMMAR line then lands in the stdout blob,
# where it carries `path:` and satisfies the very substring test that asks whether the file
# opened -- so the arm fails OPEN on its own evidence while the stderr channel reads empty.
MUT_W5='
{ if ($0 == "i108_list() { : > \"$2\"; bash \"$1\" --list \"$3\" 2>\"$2\"; }") {
    print "i108_list() { : > \"$2\"; bash \"$1\" --list \"$3\" 2>\&1; }"; next }
  print }'

# The taught passage`s opening sentence, held here so half B`s core/fixtures/ exclusion has a
# live subject rather than a hypothetical one. See A03.
OPENER='**Write it in a `derived` fence, which is what makes it checkable:**'

FIVE="analyst architect pm sm tea"

echo "derived-fence-binding: I108 — the taught derived-fence passage, its copies, and the reader that owns the grammar"

# --- Assertion 0: CONTROL -----------------------------------------------------
# The unmutated seed must pass AND print the validator's own OK line. Without the second
# conjunct a subject replaced by `exit 0` scores this green, and every negative below then
# reports a kill it did not earn.
t="$(fresh)"
out="$(run_arm "$t" I108)"; rc=$?
if [ "$rc" -eq 0 ]; then
  case "$out" in
    *"$OKLINE"*) ok "A00 the unmutated seed passes I108 and reaches its verdict (the assertions below mean something)" ;;
    *)           bad "FIXTURE BROKEN — the unmutated seed exited 0 but printed no verdict line, so the run did not reach the end of the validator"; fails=$((fails + 1)) ;;
  esac
else
  bad "FIXTURE BROKEN — the unmutated seed does not pass I108 (rc=$rc). Every assertion below would be a false pass. The validator said: $out"
  printf '\nderived-fence-binding: FIXTURE BROKEN\n'
  exit 2
fi

# --- Assertion 1: half A — a drift inside the passage body --------------------
t="$(fresh)"
if edit "$t" "core/team-roles/sm.md" "$MUT_DRIFT"; then
  says I108 "A01 half A  one of the five teaching a different word INSIDE the passage is REPORTED" \
       "$t" "the taught derivation-fence passage has forked"
fi

# --- Assertion 2: half A — the extractor loses its closing delimiter ----------
# Reworded in ALL FIVE, so no copy is left to disagree with. An awk range whose closing pattern
# never matches runs to end of file; without the guard this arm carries, five intact passages
# with five different tails would report as a fork and send the reader to the wrong repair.
t="$(fresh)"
brk=0
for r in $FIVE; do
  edit "$t" "core/team-roles/$r.md" "$MUT_CLOSE" || { brk=1; break; }
done
if [ "$brk" -eq 0 ]; then
  says I108 "A02 half A  a passage whose CLOSING delimiter is gone is reported as VACUOUS, not as a fork" \
       "$t" "cannot find the taught derivation-fence passage"
fi

# --- Assertion 3: half B — a sixth copy --------------------------------------
# THE OPENER IS WRITTEN FROM $OPENER, NOT COPIED OUT OF A ROLE FILE, AND THAT IS DELIBERATE.
# Half B excludes everything under core/fixtures/ from its scan, and an exclusion needs a
# reason that is TRUE: the recorded one is that a battery proving this arm may legitimately
# have to seed the opener. Holding the sentence in this file makes that concrete rather than
# hypothetical, and it is what the arm's own false-positive paragraph now names.
#
# A00 AND A03 TOGETHER ARE THE ACQUITTAL PROBE for that exclusion. A00 requires the unmutated
# tree to be GREEN while this file carries the opener; A03 requires a copy under
# core/team-roles/ to be REPORTED. One without the other would leave a blanket acquittal
# indistinguishable from a scoped one.
t="$(fresh)"
printf '%s\n' "$OPENER" > "$t/core/team-roles/zz-newrole.md"
if grep -qxF -- "$OPENER" "$t/core/team-roles/zz-newrole.md"; then
  says I108 "A03 half B  a SIXTH copy of the passage in an unbound file is REPORTED" \
       "$t" "outside the five bound role files carry the taught derivation-fence passage"
else
  bad "FIXTURE BROKEN — the sixth copy was not written, so A03 tested a clean tree"
fi

# --- Assertions 3b-3e: half B's ROOTS, one plant each, plus the acquittal -----
# Each root is scanned because an agent is handed those files as instruction; docs/ is not,
# because a quotation there is a citation. A root that is scanned and a root that is not are
# byte-indistinguishable from a green run, so both directions are asserted.
plant_root() {  # plant_root <label> <tree> <relative path> <want|acquit>
  local label="$1" t="$2" rel="$3" mode="$4" dir
  dir="$(dirname "$t/$rel")"
  mkdir -p "$dir"
  printf '%s\n' "$OPENER" > "$t/$rel"
  if ! grep -qxF -- "$OPENER" "$t/$rel"; then
    bad "FIXTURE BROKEN — could not plant a sixth copy at $rel, so $label tested a clean tree"
    return
  fi
  if [ "$mode" = want ]; then
    says I108 "$label" "$t" "outside the five bound role files carry the taught derivation-fence passage"
  else
    local out rc
    out="$(run_arm "$t" I108)"; rc=$?
    guard_sel "$rc" "$out" || return
    case "$out" in
      *"outside the five bound role files"*)
        bad "$label — the arm REPORTED it. That root is deliberately unscanned; flagging it turns every citation of the passage into a build failure." ;;
      *"$OKLINE"*) ok "$label" ;;
      *) bad "$label — the arm neither reported the plant nor reached a green verdict (rc=$rc), so the acquittal is a run that died rather than a root correctly left alone." ;;
    esac
  fi
}
t="$(fresh)"; plant_root "A03b half B  a copy under patterns/ is REPORTED (install.sh ships patterns/*.md into a consumer)" "$t" "patterns/zz-planted.md" want
t="$(fresh)"; plant_root "A03c half B  a copy in the root CLAUDE.md is REPORTED" "$t" "CLAUDE.md" want
t="$(fresh)"; plant_root "A03d half B  a copy under .claude/rules/ is REPORTED" "$t" ".claude/rules/zz-planted.md" want
t="$(fresh)"; plant_root "A03e half B  a copy under docs/ is ACQUITTED (a citation, not a copy)" "$t" "docs/zz-planted.md" acquit

# --- Assertion 4: half C — the taught fence stops opening ---------------------
# All five drift TOGETHER, which is what an author correcting the grammar in five places
# produces. Half A is silent by construction here; only half C, which asks the reader, can see
# it. That is the subject half C owns and no other half can reach.
t="$(fresh)"
brk=0
for r in $FIVE; do
  edit "$t" "core/team-roles/$r.md" "$MUT_INFO" || { brk=1; break; }
done
if [ "$brk" -eq 0 ]; then
  says I108 "A04 half C  five copies drifting TOGETHER to a form the reader cannot open is REPORTED" \
       "$t" "core/team-roles/analyst.md"
fi

# --- Assertion 5: half C — the RECORD TEMPLATE's fence stops opening ----------
# remediator.md carries no taught passage, so halves A and B cannot see this file at all.
t="$(fresh)"
if edit "$t" "core/team-roles/remediator.md" "$MUT_TEMPLATE"; then
  says I108 "A05 half C  a record template whose fence the reader cannot open is REPORTED" \
       "$t" "core/team-roles/remediator.md"
fi

# --- Assertion 6: the reader stops honouring the INDENT rule ------------------
# The taught passage states the fence may be indented. This asserts that statement is bound to
# the program that decides it: with the reader made indent-blind, I108's probe refuses to read
# the corpus and names the indented shape.
t="$(fresh)"
if edit "$t" "$READER" "$MUT_READER_FLAT"; then
  says I108 "A06 the probe REFUSES when the reader stops opening an INDENTED fence, which the passage teaches is read" \
       "$t" "probe scored 1000000000 "
fi

# --- Assertion 7: the reader stops requiring an exact info string -------------
t="$(fresh)"
if edit "$t" "$READER" "$MUT_READER_WIDE"; then
  says I108 "A07 the probe REFUSES when the reader opens a fence whose info string carries a trailing word" \
       "$t" "probe scored 10000000000 "
fi

# --- Assertion 8: WRONG FIX W1 — compare only the opener line -----------------
# Built on A01's tree, where the drift is in the passage BODY. The correct arm reports it; an
# arm that extracts only the opening sentence cannot, and stays green.
t="$(fresh)"
if edit "$t" "core/team-roles/sm.md" "$MUT_DRIFT"; then
  says I108 "A08a W1's tree is an offender: the shipped arm reports the body drift" \
       "$t" "the taught derivation-fence passage has forked"
  if edit "$t" "$ARM" "$MUT_W1"; then
    out="$(run_arm "$t" I108)"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"the taught derivation-fence passage has forked"*)
          bad "A08b W1 (an arm comparing only the OPENER line) still reported the body drift, so shortening the extraction changed no cell and this tree does not separate the two implementations" ;;
        *"probe scored 10000100 "*)
          ok "A08b W1 (an arm extracting only the OPENER line) is KILLED by the probe on BOTH body bits — 100, two passages differing by one word, and 10000000, two differing only in the leading blanks of their fence" ;;
        *)
          bad "A08b W1 reported neither the fork nor a probe refusal (rc=$rc). An arm that compares openers would ship, green, over five copies teaching five different bodies." ;;
      esac
    fi
  fi
fi

# --- Assertion 9: WRONG FIX W2 — bind four of the five ------------------------
# The drift is seeded in tea.md, the copy W2 drops. Half A goes blind, and what is asserted is
# that half B is what catches it — the two halves are recorded here as NOT redundant, in the
# one direction where one covers the other.
t="$(fresh)"
if edit "$t" "core/team-roles/tea.md" "$MUT_DRIFT"; then
  says I108 "A09a W2's tree is an offender: the shipped arm reports the drift in tea.md" \
       "$t" "the taught derivation-fence passage has forked"
  if edit "$t" "$ARM" "$MUT_W2"; then
    out="$(run_arm "$t" I108)"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"the taught derivation-fence passage has forked"*)
          bad "A09b W2 (an arm binding FOUR of the five) still reported the fork, so dropping a copy from i108_declared changed no cell and this tree does not separate the two implementations" ;;
        *"outside the five bound role files carry the taught derivation-fence passage"*)
          ok "A09b W2 (an arm binding FOUR of the five) goes blind to the drift and is KILLED by half B, which reports the unbound copy" ;;
        *)
          bad "A09b W2 reported NEITHER the fork nor an unbound copy (rc=$rc), so a copy dropped from the declared set is invisible to every half. The four-of-five wrong fix would ship." ;;
      esac
    fi
  fi
fi

# --- Assertion 10: WRONG FIX W3 — key half C on the token that drifts ---------
# Built on A05's tree. This is the arm's own first cut, and the population key is the whole of
# it: keyed on a fence opener, remediator.md leaves the population the moment its opener is
# renamed, and the arm reports a clean tree over the one file it was written to catch.
t="$(fresh)"
if edit "$t" "core/team-roles/remediator.md" "$MUT_TEMPLATE"; then
  says I108 "A10a W3's tree is an offender: the shipped arm names remediator.md" \
       "$t" "core/team-roles/remediator.md"
  if edit "$t" "$ARM" "$MUT_W3"; then
    out="$(run_arm "$t" I108)"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"core/team-roles/remediator.md"*)
          bad "A10b W3 (half C keyed on the fence opener) still named remediator.md, so the population key is not what this assertion claims it is and the tree does not separate the two implementations" ;;
        *"probe scored 1000000 "*)
          ok "A10b W3 (half C keyed on the FENCE OPENER, the token that drifts) is KILLED by the probe, which requires the population to take a file anchored on the record field alone" ;;
        *)
          bad "A10b W3 reported neither remediator.md nor a probe refusal (rc=$rc). A population keyed on the drifting token would ship, silently, over the one file it exists to catch." ;;
      esac
    fi
  fi
fi

# --- Assertion 11: half A — a fork in LEADING BLANKS ONLY ---------------------
# Nothing else in this file, and nothing in the entry's receipt, seeds whitespace: every other
# offender changes a word. A comparison that normalised leading blanks would pass all of them,
# which is what makes this seed load-bearing rather than a fourth way of saying A01.
t="$(fresh)"
if edit "$t" "core/team-roles/analyst.md" "$MUT_INDENT"; then
  says I108 "A11 half A  one copy whose taught fence is INDENTED where the other four sit at column 0 is REPORTED" \
       "$t" "the taught derivation-fence passage has forked"
fi

# --- Assertion 12: WRONG FIX W4 — normalise leading blanks --------------------
# Built on A11's tree, and it is the only tree that separates the two implementations. W4
# survives the probe, survives every other assertion here, and survives the entry's receipt.
t="$(fresh)"
if edit "$t" "core/team-roles/analyst.md" "$MUT_INDENT"; then
  says I108 "A12a W4's tree is an offender: the shipped arm reports the leading-blank fork" \
       "$t" "the taught derivation-fence passage has forked"
  if edit "$t" "$ARM" "$MUT_W4"; then
    out="$(run_arm "$t" I108)"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"the taught derivation-fence passage has forked"*)
          bad "A12b W4 (a comparison that strips leading blanks) still reported the fork, so the normalisation changed no cell and this tree does not separate the two implementations" ;;
        *"$OKLINE"*)
          ok "A12b W4 (a comparison that STRIPS LEADING BLANKS) is KILLED — it goes green on a copy whose fence is indented where the others are not" ;;
        *)
          bad "A12b W4 stayed silent about the fork but did NOT reach a green verdict (rc=$rc), so the silence is a run that died rather than a comparison that went blind." ;;
      esac
    fi
  fi
fi

# --- Assertion 13: half C — a taught block the reader cannot CLOSE ------------
# The case that is green everywhere else: --list exits 0 whatever its failure counter says, and
# the same file still prints a derivation row on stdout, so an arm reading only stdout acquits
# it. Applied to all five, so half A is silent by construction.
t="$(fresh)"
brk=0
for r in $FIVE; do
  edit "$t" "core/team-roles/$r.md" "$MUT_UNCLOSED" || { brk=1; break; }
done
if [ "$brk" -eq 0 ]; then
  says I108 "A13 half C  a taught fence the reader opens and never sees CLOSED is REPORTED from its STDERR" \
       "$t" "open a derivation fence the reader never sees CLOSED"
fi

# --- Assertion 14: WRONG FIX W5 — merge the reader's two streams --------------
# Built on A13's tree. Merging with 2>&1 is the natural-looking simplification and it fails
# OPEN: the GRAMMAR line carries the path and a colon, which is exactly the substring the
# opened-a-block test looks for, so the broken file answers its own question.
t="$(fresh)"
brk=0
for r in $FIVE; do
  edit "$t" "core/team-roles/$r.md" "$MUT_UNCLOSED" || { brk=1; break; }
done
if [ "$brk" -eq 0 ]; then
  says I108 "A14a W5's tree is an offender: the shipped arm reports the unclosed block" \
       "$t" "open a derivation fence the reader never sees CLOSED"
  if edit "$t" "$ARM" "$MUT_W5"; then
    out="$(run_arm "$t" I108)"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"open a derivation fence the reader never sees CLOSED"*)
          bad "A14b W5 (the reader's streams merged with 2>&1) still reported the unclosed block, so the merge changed no cell and this tree does not separate the two implementations" ;;
        *"probe scored 100000000000 "*)
          ok "A14b W5 (the reader's two streams MERGED with 2>&1) is KILLED by the probe, whose stderr channel reads empty when the merge takes it" ;;
        *"$OKLINE"*)
          bad "A14b W5 went fully GREEN. The merge is not caught by the probe either, so an arm reading a merged stream would ship and acquit every unclosable taught block." ;;
        *)
          bad "A14b W5 reported neither the unclosed block nor a probe refusal (rc=$rc)." ;;
      esac
    fi
  fi
fi

# --- Assertion 15: the reader is ABSENT ---------------------------------------
# The dedicated refusal must be the message that fires, and the probe's must not: measured on
# an earlier cut of this arm, the file test sat INSIDE the corpus block, the probe's own guard
# left its reader output empty, and the refusal the header cited as evidence appeared zero
# times while the probe's appeared once. Halves A and B must also still run — a deleted reader
# must not hide a forked passage — so the fork is seeded in the same tree.
t="$(fresh)"
rm -f "$t/$READER"
if [ -e "$t/$READER" ]; then
  bad "FIXTURE BROKEN — the reader was not removed, so A15 tested a tree with its subject present"
elif edit "$t" "core/team-roles/sm.md" "$MUT_DRIFT"; then
  out="$(run_arm "$t" I108)"; rc=$?
  if guard_sel "$rc" "$out"; then
    case "$out" in
      *"I108's probe scored"*)
        bad "A15 with the reader deleted the PROBE refused. The dedicated message is then unreachable, and the arm reports a broken probe where the truth is a missing subject — which sends the reader to the wrong repair." ;;
      *"I108 cannot find core/scripts/validate-artifact-derivations.sh"*)
        case "$out" in
          *"the taught derivation-fence passage has forked"*)
            ok "A15 a deleted reader fires the DEDICATED refusal, not the probe, and halves A and B still report the fork seeded beside it" ;;
          *)
            bad "A15 the dedicated refusal fired, but the fork seeded in the same tree was NOT reported — a deleted reader is hiding halves A and B." ;;
        esac ;;
      *)
        bad "A15 with the reader deleted the arm reported neither refusal (rc=$rc). A missing subject is being skipped in silence." ;;
    esac
  fi
fi

# --- I121: the verify-shape paragraph in every role contract -------------------
# I121 binds one paragraph into every file matching core/team-roles/*.md, byte-identical, once
# each, as its own paragraph, with no copy elsewhere, and with the validator path it names
# resolving to the derivations reader. Every half is absence-shaped, so every offender below is
# presence-shaped: each demands the specific message that names it. The three wrong arms are
# built on trees the shipped arm reports, and each is scored on the mechanism that kills it.
#
# The opener sentence is held here for the same reason OPENER is: half B excludes core/fixtures/,
# and A27 below plants a copy under core/fixtures/ that must be ACQUITTED while A26 plants one
# under core/skills/ that must be REPORTED. Together they are the probe that the exclusion is
# scoped rather than a blanket acquittal.
OPENER2='**Verify with one read-only command per Bash call.**'
run_i121_out() { run_arm "$1" I121; }

# Remove the whole paragraph, opener to closing line.
MUT_I121_DROP='
index($0, "**Verify with one read-only command per Bash call.**") == 1 { skip = 1 }
skip { if ($0 == "no command-prefix allow rule and can stop an unattended sprint until a human approves it.") skip = 0; next }
{ print }'
# The opener glued onto the end of another sentence, the paragraph otherwise intact.
MUT_I121_INLINE='
index($0, "**Verify with one read-only command per Bash call.**") == 1 { print "Some other sentence. " $0; next }
{ print }'
# The fence pointer deleted from one copy: the teammate is no longer told which validator replays it.
MUT_I121_PTR='
$0 == "by one call to `scripts/ai-dlc/validate-artifact-derivations.sh <that file>`, or one read-only" { print "by one validator call, or one read-only"; next }
{ print }'
# One word of the body changed in one copy.
MUT_I121_WORD='
$0 == "lines of shell; write each path literally, because a fence has no variables. A test, build or" { print "lines of shell; write each path plainly, because a fence has no variables. A test, build or"; next }
{ print }'
# The validator path renamed in EVERY copy, so half A stays quiet and only half C can see it.
MUT_I121_PTRALL='
$0 == "by one call to `scripts/ai-dlc/validate-artifact-derivations.sh <that file>`, or one read-only" { print "by one call to `scripts/ai-dlc/validate-derivations.sh <that file>`, or one read-only"; next }
{ print }'
# CONTROL MUTANT for the self-exemption: half B stops reading scripts/. The control must fire
# rather than the exemption hiding a scan that no longer reaches this file.
MUT_I121_ROOTS='
$0 == "        \"$REPO_ROOT/core\" \"$REPO_ROOT/scripts\" \"$REPO_ROOT/templates\" \\" { print "        \"$REPO_ROOT/core\" \"$REPO_ROOT/templates\" \\"; next }
{ print }'
# WRONG ARM W6: the block keeps only its OPENER line, so half A compares openers.
MUT_W6='
$0 == "      if (on) { buf = buf $0 \"\\n\"; if ($0 == cl) { on = 0; closed = 1; jc = 1 } }" { print "      if (on) { if (buf == \"\") buf = $0 \"\\n\"; if ($0 == cl) { on = 0; closed = 1; jc = 1 } }"; next }
{ print }'
# WRONG ARM W7: the population HAND-LISTED as the eight files the first contract named.
MUT_W7='
index($0, "i121_pop() { for i121_pf in \"$1\"/*.md;") == 1 { sub(/"\$1"\/\*\.md/, "\"$1\"/analyst.md \"$1\"/architect.md \"$1\"/pm.md \"$1\"/sm.md \"$1\"/tea.md \"$1\"/remediator.md \"$1\"/ops.md \"$1\"/adversary.md"); print; next }
{ print }'
# WRONG ARM W8: the opener keyed as a SUBSTRING rather than a whole line with a blank above it.
MUT_W8='
$0 == "      if ($0 == op && prev == \"\") { nex++; if (nex == 1) on = 1 }" { print "      if (index($0, sn)) { nex++; if (nex == 1) on = 1 }"; next }
{ print }'

I121_MISSING="do not carry the verify-shape paragraph"
I121_INLINE="opener sentence appears inside another line or paragraph in"
I121_FORK="the verify-shape paragraph has forked"
I121_EXTRA="outside core/team-roles/*.md carry the verify-shape opener sentence"
I121_PTRMSG="tells the teammate to run scripts/ai-dlc/validate-derivations.sh"
I121_CTL="I121's site scan did not find scripts/validate-enforcement-map.sh"

# --- A20: I121 CONTROL ---------------------------------------------------------
t="$(fresh)"
out="$(run_i121_out "$t")"; rc=$?
if guard_sel "$rc" "$out"; then
  case "$rc:$out" in
    *"FAIL: I121"*) bad "A20 I121 CONTROL — the unmutated seed fails I121 (rc=$rc), so every assertion below would be a false pass. It said: $out" ;;
    0:*"$OKLINE"*)  ok "A20 I121 CONTROL: the unmutated seed passes --arms I121 and reaches its verdict" ;;
    *)              bad "A20 I121 CONTROL — no I121 finding, but no verdict line either (rc=$rc), so the silence is a run that died" ;;
  esac
fi

# --- A21: the paragraph dropped from ONE role file -----------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/adversary.md" "$MUT_I121_DROP"; then
  says I121 "A21 half A  the paragraph dropped from adversary.md is REPORTED as missing, by name" \
       "$t" "$I121_MISSING: core/team-roles/adversary.md"
fi

# --- A22: the paragraph present ONLY in remediator.md --------------------------
# The shape a remediator-only fix produces. Every other role file must be named and remediator
# must not be: an arm that reported "something is missing" without naming the files, or that
# named the one file that carries it, would pass a looser assertion.
t="$(fresh)"
brk=0
for f in "$t"/core/team-roles/*.md; do
  r="${f##*/}"
  [ "$r" = remediator.md ] && continue
  edit "$t" "core/team-roles/$r" "$MUT_I121_DROP" || { brk=1; break; }
done
if [ "$brk" -eq 0 ]; then
  out="$(run_i121_out "$t")"; rc=$?
  if guard_sel "$rc" "$out"; then
    miss="$(printf '%s\n' "$out" | grep -F "$I121_MISSING")"
    case "$miss" in
      *"core/team-roles/remediator.md"*) bad "A22 half A  remediator.md, the one file carrying the paragraph, was named as missing it (rc=$rc)" ;;
      *"core/team-roles/adversary.md"*"core/team-roles/ux.md"*) ok "A22 half A  the paragraph present ONLY in remediator.md reports every other role file, first to last, and not remediator" ;;
      *) bad "A22 half A  the paragraph present only in remediator.md was not reported against the other role files (rc=$rc): $miss" ;;
    esac
  fi
fi

# --- A23: the opener inside another sentence -----------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I121_INLINE"; then
  says I121 "A23 half A  the opener glued onto the end of another sentence is REPORTED as inline, by name" \
       "$t" "$I121_INLINE: core/team-roles/qa.md"
fi

# --- A24: the fence pointer deleted from one copy ------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/dev.md" "$MUT_I121_PTR"; then
  says I121 "A24 half A  the fence pointer deleted from ONE copy is REPORTED as a fork naming that copy" \
       "$t" "$I121_FORK. It differs from the copy the other role files agree on, byte-for-byte from opener to closing line, in: core/team-roles/dev.md."
fi

# --- A25: one word of the body drifted -----------------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/sm.md" "$MUT_I121_WORD"; then
  says I121 "A25 half A  one word drifted in ONE body is REPORTED as a fork naming that copy" \
       "$t" "$I121_FORK. It differs from the copy the other role files agree on, byte-for-byte from opener to closing line, in: core/team-roles/sm.md."
fi

# --- A26/A27: half B, a ninth copy and the scoped exclusion --------------------
t="$(fresh)"
mkdir -p "$t/core/skills"
printf 'See the role contract.\n\n%s Do it.\n' "$OPENER2" > "$t/core/skills/zz-planted.md"
if grep -qF -- "$OPENER2" "$t/core/skills/zz-planted.md"; then
  says I121 "A26 half B  a copy of the opener under core/skills/ is REPORTED" \
       "$t" "$I121_EXTRA: core/skills/zz-planted.md"
else
  bad "FIXTURE BROKEN — the core/skills/ copy was not written, so A26 tested a clean tree"
fi
t="$(fresh)"
mkdir -p "$t/core/fixtures/zz-planted"
printf '%s\n' "$OPENER2" > "$t/core/fixtures/zz-planted/x.md"
if grep -qF -- "$OPENER2" "$t/core/fixtures/zz-planted/x.md"; then
  out="$(run_i121_out "$t")"; rc=$?
  if guard_sel "$rc" "$out"; then
    case "$out" in
      *"FAIL: I121"*) bad "A27 half B  a copy under core/fixtures/ was REPORTED (rc=$rc); the battery that proves this arm has to be able to seed the sentence" ;;
      *"$OKLINE"*)    ok "A27 half B  a copy under core/fixtures/ is ACQUITTED and the run reaches its verdict (the exclusion, scoped)" ;;
      *)              bad "A27 half B  no finding but no verdict either (rc=$rc), so the acquittal is a run that died" ;;
    esac
  fi
else
  bad "FIXTURE BROKEN — the core/fixtures/ copy was not written, so A27 tested a clean tree"
fi

# --- A28: a NEW role file with no paragraph ------------------------------------
# The population is the glob, so a role added tomorrow is in it without anyone listing it.
t="$(fresh)"
printf '# Role: Planted\n\n## Identity\n\nA role added after this arm was written.\n' > "$t/core/team-roles/zz-newrole.md"
says I121 "A28 half A  a NEW role file without the paragraph is REPORTED (the population is the glob, not a list)" \
     "$t" "$I121_MISSING: core/team-roles/zz-newrole.md"

# --- A29: half C, the validator path renamed in EVERY copy ---------------------
t="$(fresh)"
brk=0
for f in "$t"/core/team-roles/*.md; do
  edit "$t" "core/team-roles/${f##*/}" "$MUT_I121_PTRALL" || { brk=1; break; }
done
if [ "$brk" -eq 0 ]; then
  out="$(run_i121_out "$t")"; rc=$?
  if guard_sel "$rc" "$out"; then
    case "$out" in
      *"$I121_FORK"*)   bad "A29 half C  the rename in every copy was reported as a FORK, so the copies did not move together and this tree does not isolate half C" ;;
      *"$I121_PTRMSG"*) ok "A29 half C  a validator path renamed in EVERY copy, which half A cannot see, is REPORTED by half C" ;;
      *)                bad "A29 half C  the renamed validator path was not reported (rc=$rc). A teammate would be told to run a file that is not there." ;;
    esac
  fi
fi

# --- A30: the self-exemption's control fires -----------------------------------
t="$(fresh)"
if edit "$t" "$ARM" "$MUT_I121_ROOTS"; then
  says I121 "A30 half B  with scripts/ dropped from the roots the CONTROL fires, rather than the self-exemption hiding a scan that no longer reaches this file" \
       "$t" "$I121_CTL"
fi

# --- A31: WRONG ARM W6 — compare only the opener line --------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/dev.md" "$MUT_I121_PTR"; then
  says I121 "A31a W6's tree is an offender: the shipped arm reports the deleted pointer" "$t" "$I121_FORK"
  if edit "$t" "$ARM" "$MUT_W6"; then
    out="$(run_i121_out "$t")"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"$I121_FORK"*) bad "A31b W6 (opener-only compare) still reported the fork, so this tree does not separate the two implementations" ;;
        *"I121's probe scored 1000000001010 "*) ok "A31b W6 (an arm comparing only the OPENER line) is KILLED by the probe: 10 and 1000, a one-word body drift scored OK, and 1000000000000, no validator path left to resolve" ;;
        *) bad "A31b W6 reported neither the fork nor the expected probe refusal (rc=$rc): $(printf '%s\n' "$out" | grep I121 | cut -c1-200)" ;;
      esac
    fi
  fi
fi

# --- A32: WRONG ARM W7 — a hand-listed population ------------------------------
# qa.md is outside the eight files the first contract named, so it is the file a hand list drops.
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I121_DROP"; then
  says I121 "A32a W7's tree is an offender: the shipped arm names qa.md" "$t" "$I121_MISSING: core/team-roles/qa.md"
  if edit "$t" "$ARM" "$MUT_W7"; then
    out="$(run_i121_out "$t")"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"core/team-roles/qa.md"*) bad "A32b W7 (hand-listed population) still named qa.md, so this tree does not separate the two implementations" ;;
        *"I121's probe scored 1 "*) ok "A32b W7 (a HAND-LISTED population) is KILLED by the probe, which requires the population to be every *.md in the directory" ;;
        *) bad "A32b W7 reported neither qa.md nor the expected probe refusal (rc=$rc): $(printf '%s\n' "$out" | grep I121 | cut -c1-200)" ;;
      esac
    fi
  fi
fi

# --- A33: WRONG ARM W8 — the opener keyed as a substring -----------------------
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I121_INLINE"; then
  says I121 "A33a W8's tree is an offender: the shipped arm reports the inline opener" "$t" "$I121_INLINE: core/team-roles/qa.md"
  if edit "$t" "$ARM" "$MUT_W8"; then
    out="$(run_i121_out "$t")"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"$I121_INLINE"*) bad "A33b W8 (substring key) still reported the inline opener, so this tree does not separate the two implementations" ;;
        *"I121's probe scored 1101010 "*) ok "A33b W8 (the opener keyed as a SUBSTRING) is KILLED by the probe: 100000 and 1000000, the glued opener and the opener with no blank line above it both accepted, and in consequence 10, the no-blank-line seed counted an OK copy, and 1000, the glued seed counted a fork" ;;
        *) bad "A33b W8 reported neither the inline opener nor the expected probe refusal (rc=$rc): $(printf '%s\n' "$out" | grep I121 | cut -c1-200)" ;;
      esac
    fi
  fi
fi

# --- I122: the advisor paragraph in every role contract ------------------------
# I122 is built as I121 is, over the same population, for a second paragraph that sits directly
# below I121's in every role file. The battery mirrors A20-A33, and adds what only a SECOND
# paragraph in the same files needs: A46/A47 drop each paragraph in turn and require the OTHER
# arm to stay green while this one names the files, so neither arm can be satisfied by the
# neighbour's text.
#
# The opener sentence is held in a SINGLE-QUOTED variable: it carries backticks, and inside
# double quotes they would run `advisor` as a command and plant the text either side of a hole.
OPENER3='**Consult the `advisor` tool when it is available.**'
run_i122_out() { run_arm "$1" I122; }

MUT_I122_DROP='
index($0, "**Consult the `advisor` tool when it is available.**") == 1 { skip = 1 }
skip { if ($0 == "switching silently. If the tool is absent or returns an error, continue without it.") skip = 0; next }
{ print }'
MUT_I122_INLINE='
index($0, "**Consult the `advisor` tool when it is available.**") == 1 { print "Some other sentence. " $0; next }
{ print }'
# The FIRST of the two touchpoints dropped from one copy: the teammate is told to consult only
# before its verdict.
MUT_I122_WORD='
$0 == "call it before your first edit or write, and again before you write your deliverable or verdict." { print "call it before you write your deliverable or verdict."; next }
{ print }'
# CONTROL MUTANT for I122's self-exemption: half B stops reading scripts/.
MUT_I122_ROOTS='
$0 == "    i122_hits=\"$(i122_sites \"$REPO_ROOT/core\" \"$REPO_ROOT/scripts\" \\" { print "    i122_hits=\"$(i122_sites \"$REPO_ROOT/core\" \\"; next }
{ print }'
# WRONG ARM W9: the block keeps only its OPENER line.
MUT_W9='
$0 == "      if (on) { buf = buf $0 \"\\n\"; if ($0 == cl) { on = 0; closed = 1; jc = 1 } }   # i122 block" { print "      if (on) { if (buf == \"\") buf = $0 \"\\n\"; if ($0 == cl) { on = 0; closed = 1; jc = 1 } }   # i122 block"; next }
{ print }'
# WRONG ARM W10: the population HAND-LISTED.
MUT_W10='
index($0, "i122_pop() { for i122_pf in \"$1\"/*.md;") == 1 { sub(/"\$1"\/\*\.md/, "\"$1\"/analyst.md \"$1\"/architect.md \"$1\"/pm.md \"$1\"/sm.md \"$1\"/tea.md \"$1\"/remediator.md \"$1\"/ops.md \"$1\"/adversary.md"); print; next }
{ print }'
# WRONG ARM W11: the opener keyed as a SUBSTRING.
MUT_W11='
$0 == "      if ($0 == op && prev == \"\") { nex++; if (nex == 1) on = 1 }   # i122 opener key" { print "      if (index($0, sn)) { nex++; if (nex == 1) on = 1 }   # i122 opener key"; next }
{ print }'

I122_MISSING="do not carry the advisor paragraph"
I122_INLINE="advisor opener sentence appears inside another line or paragraph in"
I122_FORK="the advisor paragraph has forked"
I122_EXTRA="outside core/team-roles/*.md carry the advisor opener sentence"
I122_CTL="I122's site scan did not find scripts/validate-enforcement-map.sh"

# --- A34: I122 CONTROL ---------------------------------------------------------
t="$(fresh)"
out="$(run_i122_out "$t")"; rc=$?
if guard_sel "$rc" "$out"; then
  case "$rc:$out" in
    *"FAIL: I122"*) bad "A34 I122 CONTROL — the unmutated seed fails I122 (rc=$rc), so every assertion below would be a false pass. It said: $out" ;;
    0:*"$OKLINE"*)  ok "A34 I122 CONTROL: the unmutated seed passes --arms I122 and reaches its verdict" ;;
    *)              bad "A34 I122 CONTROL — no I122 finding, but no verdict line either (rc=$rc), so the silence is a run that died" ;;
  esac
fi

# --- A35: the paragraph dropped from ONE role file -----------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/adversary.md" "$MUT_I122_DROP"; then
  says I122 "A35 half A  the advisor paragraph dropped from adversary.md is REPORTED as missing, by name" \
       "$t" "$I122_MISSING: core/team-roles/adversary.md"
fi

# --- A36: the paragraph present ONLY in remediator.md --------------------------
t="$(fresh)"
brk=0
for f in "$t"/core/team-roles/*.md; do
  r="${f##*/}"
  [ "$r" = remediator.md ] && continue
  edit "$t" "core/team-roles/$r" "$MUT_I122_DROP" || { brk=1; break; }
done
if [ "$brk" -eq 0 ]; then
  out="$(run_i122_out "$t")"; rc=$?
  if guard_sel "$rc" "$out"; then
    miss="$(printf '%s\n' "$out" | grep -F "$I122_MISSING")"
    case "$miss" in
      *"core/team-roles/remediator.md"*) bad "A36 half A  remediator.md, the one file carrying the paragraph, was named as missing it (rc=$rc)" ;;
      *"core/team-roles/adversary.md"*"core/team-roles/ux.md"*) ok "A36 half A  the advisor paragraph present ONLY in remediator.md reports every other role file, first to last, and not remediator" ;;
      *) bad "A36 half A  the paragraph present only in remediator.md was not reported against the other role files (rc=$rc): $miss" ;;
    esac
  fi
fi

# --- A37: the opener inside another sentence -----------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I122_INLINE"; then
  says I122 "A37 half A  the advisor opener glued onto the end of another sentence is REPORTED as inline, by name" \
       "$t" "$I122_INLINE: core/team-roles/qa.md"
fi

# --- A38: one touchpoint dropped from one body ---------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/sm.md" "$MUT_I122_WORD"; then
  says I122 "A38 half A  the first-edit touchpoint dropped from ONE body is REPORTED as a fork naming that copy" \
       "$t" "$I122_FORK. It differs from the copy the other role files agree on, byte-for-byte from opener to closing line, in: core/team-roles/sm.md."
fi

# --- A39/A40: half B, a copy outside the population and the scoped exclusion ---
t="$(fresh)"
mkdir -p "$t/core/skills"
printf 'See the role contract.\n\n%s Do it.\n' "$OPENER3" > "$t/core/skills/zz-planted.md"
if grep -qF -- "$OPENER3" "$t/core/skills/zz-planted.md"; then
  says I122 "A39 half B  a copy of the advisor opener under core/skills/ is REPORTED" \
       "$t" "$I122_EXTRA: core/skills/zz-planted.md"
else
  bad "FIXTURE BROKEN — the core/skills/ copy was not written, so A39 tested a clean tree"
fi
t="$(fresh)"
mkdir -p "$t/core/fixtures/zz-planted"
printf '%s\n' "$OPENER3" > "$t/core/fixtures/zz-planted/x.md"
if grep -qF -- "$OPENER3" "$t/core/fixtures/zz-planted/x.md"; then
  out="$(run_i122_out "$t")"; rc=$?
  if guard_sel "$rc" "$out"; then
    case "$out" in
      *"FAIL: I122"*) bad "A40 half B  a copy under core/fixtures/ was REPORTED (rc=$rc); the battery that proves this arm has to be able to seed the sentence" ;;
      *"$OKLINE"*)    ok "A40 half B  a copy of the advisor opener under core/fixtures/ is ACQUITTED and the run reaches its verdict (the exclusion, scoped)" ;;
      *)              bad "A40 half B  no finding but no verdict either (rc=$rc), so the acquittal is a run that died" ;;
    esac
  fi
else
  bad "FIXTURE BROKEN — the core/fixtures/ copy was not written, so A40 tested a clean tree"
fi

# --- A41: a NEW role file with no paragraph ------------------------------------
t="$(fresh)"
printf '# Role: Planted\n\n## Identity\n\nA role added after this arm was written.\n' > "$t/core/team-roles/zz-newrole.md"
says I122 "A41 half A  a NEW role file without the advisor paragraph is REPORTED (the population is the glob, not a list)" \
     "$t" "$I122_MISSING: core/team-roles/zz-newrole.md"

# --- A42: the self-exemption's control fires -----------------------------------
t="$(fresh)"
if edit "$t" "$ARM" "$MUT_I122_ROOTS"; then
  says I122 "A42 half B  with scripts/ dropped from I122's roots the CONTROL fires, rather than the self-exemption hiding a scan that no longer reaches this file" \
       "$t" "$I122_CTL"
fi

# --- A43: WRONG ARM W9 — compare only the opener line --------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/dev.md" "$MUT_I122_WORD"; then
  says I122 "A43a W9's tree is an offender: the shipped arm reports the dropped touchpoint" "$t" "$I122_FORK"
  if edit "$t" "$ARM" "$MUT_W9"; then
    out="$(run_i122_out "$t")"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"$I122_FORK"*) bad "A43b W9 (opener-only compare) still reported the fork, so this tree does not separate the two implementations" ;;
        *"I122's probe scored 1010 "*) ok "A43b W9 (an arm comparing only the OPENER line) is KILLED by the probe: 10 and 1000, a one-word body drift scored OK" ;;
        *) bad "A43b W9 reported neither the fork nor the expected probe refusal (rc=$rc): $(printf '%s\n' "$out" | grep I122 | cut -c1-200)" ;;
      esac
    fi
  fi
fi

# --- A44: WRONG ARM W10 — a hand-listed population -----------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I122_DROP"; then
  says I122 "A44a W10's tree is an offender: the shipped arm names qa.md" "$t" "$I122_MISSING: core/team-roles/qa.md"
  if edit "$t" "$ARM" "$MUT_W10"; then
    out="$(run_i122_out "$t")"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"core/team-roles/qa.md"*) bad "A44b W10 (hand-listed population) still named qa.md, so this tree does not separate the two implementations" ;;
        *"I122's probe scored 1 "*) ok "A44b W10 (a HAND-LISTED population) is KILLED by the probe, which requires the population to be every *.md in the directory" ;;
        *) bad "A44b W10 reported neither qa.md nor the expected probe refusal (rc=$rc): $(printf '%s\n' "$out" | grep I122 | cut -c1-200)" ;;
      esac
    fi
  fi
fi

# --- A45: WRONG ARM W11 — the opener keyed as a substring ----------------------
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I122_INLINE"; then
  says I122 "A45a W11's tree is an offender: the shipped arm reports the inline opener" "$t" "$I122_INLINE: core/team-roles/qa.md"
  if edit "$t" "$ARM" "$MUT_W11"; then
    out="$(run_i122_out "$t")"; rc=$?
    if guard_sel "$rc" "$out"; then
      case "$out" in
        *"$I122_INLINE"*) bad "A45b W11 (substring key) still reported the inline opener, so this tree does not separate the two implementations" ;;
        *"I122's probe scored 1101010 "*) ok "A45b W11 (the opener keyed as a SUBSTRING) is KILLED by the probe: 100000 and 1000000, the glued opener and the opener with no blank line above it both accepted, and in consequence 10 and 1000" ;;
        *) bad "A45b W11 reported neither the inline opener nor the expected probe refusal (rc=$rc): $(printf '%s\n' "$out" | grep I122 | cut -c1-200)" ;;
      esac
    fi
  fi
fi

# --- A46/A47: I121 AND I122 DO NOT SATISFY EACH OTHER ---------------------------
# Each paragraph dropped from EVERY role file in turn. The arm that owns it must name a file
# (adversary.md, first in the glob) and the arm that owns the OTHER paragraph must reach a clean
# verdict on the same tree. An arm keyed on its neighbour's opener or closer fails one half.
xprobe() { # xprobe <label> <drop-mutation> <owner-arm> <owner-missing-msg> <other-arm>
  local label="$1" mut="$2" own="$3" msg="$4" oth="$5" f brk=0 o1 o2 r1 r2
  t="$(fresh)"
  for f in "$t"/core/team-roles/*.md; do
    edit "$t" "core/team-roles/${f##*/}" "$mut" || { brk=1; break; }
  done
  [ "$brk" -eq 0 ] || return 0
  o1="$(run_arm "$t" "$own")"; r1=$?
  o2="$(run_arm "$t" "$oth")"; r2=$?
  guard_sel "$r1" "$o1" || return 0
  guard_sel "$r2" "$o2" || return 0
  case "$o1" in
    *"$msg: core/team-roles/adversary.md"*) ;;
    *) bad "$label — $own did not name the files its paragraph was dropped from (rc=$r1)"; return 0 ;;
  esac
  case "$r2:$o2" in
    *"FAIL: $oth"*) bad "$label — $oth reported on a tree where only $own's paragraph was dropped, so the two arms are entangled (rc=$r2)" ;;
    0:*"$OKLINE"*)  ok "$label" ;;
    *)              bad "$label — $oth reached no verdict (rc=$r2), so its silence is a run that died" ;;
  esac
}
xprobe "A46 the verify-shape paragraph dropped everywhere: I121 names the files and I122 stays green" \
       "$MUT_I121_DROP" I121 "$I121_MISSING" I122
xprobe "A47 the advisor paragraph dropped everywhere: I122 names the files and I121 stays green" \
       "$MUT_I122_DROP" I122 "$I122_MISSING" I121

# --- A48-A50: THE THREE-WAY DROP MATRIX OVER I121, I122 AND I123 -------------------
# I123 binds the chunked-write paragraph directly below I122's in every role file. Each of the
# three paragraphs is dropped from EVERY role file in turn, and all three arms are run on that
# one tree: the owner must name adversary.md as MISSING and the other two must reach a clean
# verdict. ONE CELL IS DIFFERENT BY CONSTRUCTION. I123 requires its paragraph to sit directly
# after I122's closing line, so dropping I122's paragraph moves I123's out of place: in that
# cell I123 must report MISPLACED, naming adversary.md, and must NOT report MISSING. That is a
# stronger cell than green -- it proves I123 found its paragraph by its OWN opener rather than
# by reading the advisor paragraph's text, which a green verdict cannot tell apart.
# The block ends at its first blank line, the same delimiter I123 uses, so the drop and the arm
# agree on what the paragraph is.
MUT_I123_DROP='
index($0, "**Write your deliverable in chunks and iteratively, never in one write at the end.**") == 1 { skip = 1 }
skip { if ($0 == "") skip = 0; next }
{ print }'
I123_MISSING="do not carry the chunked-write paragraph"
I123_MISPLACED="is not directly after the advisor paragraph's closing line, with exactly one blank line between, in"
# matrix_cell <label> <drop-mutation> <owner-arm> <owner-msg> <arm>:<want> ...
#   <want> is OK (clean verdict, no finding from that arm), a message that must name
#   adversary.md, or !<message> -- a message that must NOT appear in that arm's output.
matrix_cell() {
  local label="$1" mut="$2" own="$3" msg="$4" f brk=0 spec a want o r why=''
  shift 4
  t="$(fresh)"
  for f in "$t"/core/team-roles/*.md; do
    edit "$t" "core/team-roles/${f##*/}" "$mut" || { brk=1; break; }
  done
  [ "$brk" -eq 0 ] || return 0
  for spec in "$own:$msg" "$@"; do
    a="${spec%%:*}"; want="${spec#*:}"
    o="$(run_arm "$t" "$a")"; r=$?
    guard_sel "$r" "$o" || return 0
    if [ "${want#!}" != "$want" ]; then
      case "$o" in
        *"${want#!}"*) why="$why; $a reported '${want#!}', which this cell forbids (rc=$r)" ;;
      esac
    elif [ "$want" = OK ]; then
      case "$r:$o" in
        *"FAIL: $a"*) why="$why; $a reported on a tree where only $own's paragraph was dropped (rc=$r), so the arms are entangled" ;;
        0:*"$OKLINE"*) : ;;
        *) why="$why; $a reached no verdict (rc=$r), so its silence is a run that died" ;;
      esac
    else
      case "$o" in
        *"$want: core/team-roles/adversary.md"*) : ;;
        *) why="$why; $a did not report '$want' naming core/team-roles/adversary.md (rc=$r)" ;;
      esac
    fi
  done
  if [ -n "$why" ]; then bad "$label —${why#;}"; else ok "$label"; fi
}
matrix_cell "A48 matrix: verify-shape dropped everywhere — I121 names the files, I122 and I123 stay green" \
  "$MUT_I121_DROP" I121 "$I121_MISSING" I122:OK I123:OK
matrix_cell "A49 matrix: advisor dropped everywhere — I122 names the files, I121 green, I123 reports MISPLACED and not MISSING" \
  "$MUT_I122_DROP" I122 "$I122_MISSING" I121:OK "I123:$I123_MISPLACED" "I123:!$I123_MISSING"
matrix_cell "A50 matrix: chunked-write dropped everywhere — I123 names the files, I121 and I122 stay green" \
  "$MUT_I123_DROP" I123 "$I123_MISSING" I121:OK I122:OK

# --- I75: the seeded-drift oracle (BL-269) ------------------------------------
# I75 had no fixture anywhere, and its finding sets are EMPTY on a clean tree -- every subject
# hashes to the one modal chain -- so a before/after comparison around any rewrite of it compares
# two empty sets. These arms seed the two defects it exists for, one property apart from a
# near-miss, so a batching rewrite has something to be equivalent to. HOSTED HERE, not in the
# enforcement-map batteries, because this fixture already drives `--arms` against a whole-tree
# seed carrying core/scripts/; the I108 name of the file is its origin, not its limit.
#
# The subject is audit-upstream-routing.sh: its root block carries the canonical chain with the
# `exit 2` terminal guard on its own line, so each mutation below is a one-line edit INSIDE the
# block, and `edit` refuses it if the anchor moved.
I75_SUBJ="core/scripts/audit-upstream-routing.sh"
run_i75() { bash "$1/$ARM" --arms I75 2>&1; }
i75_case() { # <label> <tree> <want-substring|OK> — presence-shaped both ways
  local label="$1" t="$2" want="$3" out rc
  out="$(run_i75 "$t")"; rc=$?
  if [ "$rc" = 2 ]; then
    bad "$label — FIXTURE BROKEN: --arms I75 exited 2, a selection failure, so nothing was checked. The validator said: $(printf '%s' "$out" | head -3)"
    return
  fi
  if [ "$want" = OK ]; then
    case "$out" in
      *"I75"*) bad "$label — I75 reported on a tree it must acquit (rc=$rc): $(printf '%s\n' "$out" | grep I75 | cut -c1-200)" ;;
      *"$OKLINE"*) ok "$label" ;;
      *) bad "$label — no I75 finding, but no verdict line either (rc=$rc), so the silence is not an acquittal" ;;
    esac
  else
    case "$out" in
      *"$want"*"${I75_SUBJ##*/}"*) ok "$label" ;;
      *) bad "$label — I75 did not report the seeded subject (rc=$rc). Its finding set stays empty on a tree that carries the defect, which reads exactly like a clean tree." ;;
    esac
  fi
}

t="$(fresh)"
i75_case "A16 I75 CONTROL: the unmutated seed passes --arms I75 and reaches its verdict" "$t" OK

# The override read moved BELOW the CLAUDE_PROJECT_DIR fallback: the precedence that answers
# about whichever repo the session started in.
t="$(fresh)"
if edit "$t" "$I75_SUBJ" '
  /^# --- AI_DLC_ROOT ---/ { inb = 1 }
  inb && $0 == "AI_DLC_ROOT=\"${AI_DLC_PROJECT_ROOT:-}\"" { held = $0; next }
  inb && held != "" && $0 == "[ -n \"$AI_DLC_ROOT\" ] || AI_DLC_ROOT=\"${CLAUDE_PROJECT_DIR:-}\"" { print "AI_DLC_ROOT=\"${CLAUDE_PROJECT_DIR:-}\""; print "[ -n \"$AI_DLC_ROOT\" ] || AI_DLC_ROOT=\"${AI_DLC_PROJECT_ROOT:-}\""; held = ""; next }
  /^# --- end AI_DLC_ROOT ---/ { inb = 0 }
  { print }'; then
  i75_case "A17 I75 a root chain reading CLAUDE_PROJECT_DIR before the override is REPORTED as drift, by name" "$t" "precedence chain differs from the canonical one"
fi

# The terminal guard gone: an unresolved root leaves the variable empty.
t="$(fresh)"
if edit "$t" "$I75_SUBJ" '
  /^# --- AI_DLC_ROOT ---/ { inb = 1 }
  inb && $0 == "  exit 2" { print "  :"; next }
  /^# --- end AI_DLC_ROOT ---/ { inb = 0 }
  { print }'; then
  i75_case "A18 I75 a root chain with no terminal guard is REPORTED as not failing closed, by name" "$t" "does not fail closed"
fi

# NEAR-MISS: a comment inside the block reworded. I75 compares EXECUTABLE lines, so prose that
# differs per script -- the house style -- must not read as drift.
t="$(fresh)"
if edit "$t" "$I75_SUBJ" '
  /^# --- AI_DLC_ROOT ---/ { inb = 1; print; next }
  inb && !done && /^# / { print "# (reworded) " substr($0, 3); done = 1; next }
  /^# --- end AI_DLC_ROOT ---/ { inb = 0 }
  { print }'; then
  i75_case "A19 I75 a reworded COMMENT inside the root block is acquitted and the run reaches its verdict" "$t" OK
fi

# --- Verdict ------------------------------------------------------------------
# THE COUNT IS ASSERTED. A driver whose `for` loop or `if` guard stopped reaching an assertion
# prints fewer lines and no failure, and an unrun assertion is indistinguishable from one that
# passed.
EXPECTED=66
if [ "$asserted" -ne "$EXPECTED" ]; then
  printf '\nderived-fence-binding: FIXTURE BROKEN — %d assertions ran, %d were declared. An assertion that never ran reads exactly like one that passed.\n' "$asserted" "$EXPECTED"
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  printf '\nderived-fence-binding: PASS (%d assertions)\n' "$asserted"
  exit 0
fi
printf '\nderived-fence-binding: FAIL (%d of %d assertions)\n' "$fails" "$asserted"
exit 1
