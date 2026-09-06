#!/usr/bin/env bash
# derived-fence-binding — assert invariant I108 both fires and discriminates.
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

# run_arm <tree> — run ONLY I108's unit in that tree and print its combined output. A selected
# run costs the validator's prologue plus one arm instead of every invariant scanning a tree
# this fixture does not care about.
run_arm() {
  bash "$1/$ARM" --arms I108 2>&1
}

# guard_sel <rc> <output> — a validator exit of 2 is a SELECTION or generated-subprogram
# failure and never an invariant violation. Nothing was checked, so it must not be scored as a
# mutant surviving OR as one dying; the second reading is the dangerous one because it prints
# ok.
guard_sel() {
  [ "$1" = "2" ] || return 0
  bad "FIXTURE BROKEN — 'validate-enforcement-map.sh --arms I108' exited 2. That is a selection or usage failure, so NOTHING was checked here. The validator said: $2"
  return 1
}

# says <label> <tree> <expected substring> — the arm must REPORT it.
says() {
  local label="$1" t="$2" want="$3" out rc
  out="$(run_arm "$t")"; rc=$?
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
out="$(run_arm "$t")"; rc=$?
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
  says "A01 half A  one of the five teaching a different word INSIDE the passage is REPORTED" \
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
  says "A02 half A  a passage whose CLOSING delimiter is gone is reported as VACUOUS, not as a fork" \
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
  says "A03 half B  a SIXTH copy of the passage in an unbound file is REPORTED" \
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
    says "$label" "$t" "outside the five bound role files carry the taught derivation-fence passage"
  else
    local out rc
    out="$(run_arm "$t")"; rc=$?
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
  says "A04 half C  five copies drifting TOGETHER to a form the reader cannot open is REPORTED" \
       "$t" "core/team-roles/analyst.md"
fi

# --- Assertion 5: half C — the RECORD TEMPLATE's fence stops opening ----------
# remediator.md carries no taught passage, so halves A and B cannot see this file at all.
t="$(fresh)"
if edit "$t" "core/team-roles/remediator.md" "$MUT_TEMPLATE"; then
  says "A05 half C  a record template whose fence the reader cannot open is REPORTED" \
       "$t" "core/team-roles/remediator.md"
fi

# --- Assertion 6: the reader stops honouring the INDENT rule ------------------
# The taught passage states the fence may be indented. This asserts that statement is bound to
# the program that decides it: with the reader made indent-blind, I108's probe refuses to read
# the corpus and names the indented shape.
t="$(fresh)"
if edit "$t" "$READER" "$MUT_READER_FLAT"; then
  says "A06 the probe REFUSES when the reader stops opening an INDENTED fence, which the passage teaches is read" \
       "$t" "probe scored 1000000000 "
fi

# --- Assertion 7: the reader stops requiring an exact info string -------------
t="$(fresh)"
if edit "$t" "$READER" "$MUT_READER_WIDE"; then
  says "A07 the probe REFUSES when the reader opens a fence whose info string carries a trailing word" \
       "$t" "probe scored 10000000000 "
fi

# --- Assertion 8: WRONG FIX W1 — compare only the opener line -----------------
# Built on A01's tree, where the drift is in the passage BODY. The correct arm reports it; an
# arm that extracts only the opening sentence cannot, and stays green.
t="$(fresh)"
if edit "$t" "core/team-roles/sm.md" "$MUT_DRIFT"; then
  says "A08a W1's tree is an offender: the shipped arm reports the body drift" \
       "$t" "the taught derivation-fence passage has forked"
  if edit "$t" "$ARM" "$MUT_W1"; then
    out="$(run_arm "$t")"; rc=$?
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
  says "A09a W2's tree is an offender: the shipped arm reports the drift in tea.md" \
       "$t" "the taught derivation-fence passage has forked"
  if edit "$t" "$ARM" "$MUT_W2"; then
    out="$(run_arm "$t")"; rc=$?
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
  says "A10a W3's tree is an offender: the shipped arm names remediator.md" \
       "$t" "core/team-roles/remediator.md"
  if edit "$t" "$ARM" "$MUT_W3"; then
    out="$(run_arm "$t")"; rc=$?
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
  says "A11 half A  one copy whose taught fence is INDENTED where the other four sit at column 0 is REPORTED" \
       "$t" "the taught derivation-fence passage has forked"
fi

# --- Assertion 12: WRONG FIX W4 — normalise leading blanks --------------------
# Built on A11's tree, and it is the only tree that separates the two implementations. W4
# survives the probe, survives every other assertion here, and survives the entry's receipt.
t="$(fresh)"
if edit "$t" "core/team-roles/analyst.md" "$MUT_INDENT"; then
  says "A12a W4's tree is an offender: the shipped arm reports the leading-blank fork" \
       "$t" "the taught derivation-fence passage has forked"
  if edit "$t" "$ARM" "$MUT_W4"; then
    out="$(run_arm "$t")"; rc=$?
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
  says "A13 half C  a taught fence the reader opens and never sees CLOSED is REPORTED from its STDERR" \
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
  says "A14a W5's tree is an offender: the shipped arm reports the unclosed block" \
       "$t" "open a derivation fence the reader never sees CLOSED"
  if edit "$t" "$ARM" "$MUT_W5"; then
    out="$(run_arm "$t")"; rc=$?
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
  out="$(run_arm "$t")"; rc=$?
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

# --- Verdict ------------------------------------------------------------------
# THE COUNT IS ASSERTED. A driver whose `for` loop or `if` guard stopped reaching an assertion
# prints fewer lines and no failure, and an unrun assertion is indistinguishable from one that
# passed.
EXPECTED=25
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
