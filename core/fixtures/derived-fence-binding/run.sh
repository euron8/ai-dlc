#!/usr/bin/env bash
# derived-fence-binding — assert invariant I108 both fires and discriminates.
# Also hosts I75's seeded-drift oracle (A16-A19, and A51-A53 on real-sized spans), which had no fixture anywhere, and I121's
# battery (A20-A29, A31a-A33a): the verify-shape paragraph every role contract carries.
# And I122's battery (A34-A41, A43a-A45a, A46-A47): the advisor paragraph directly below it in every role
# contract, and a cross-probe that neither arm is satisfied by the other's text.
# And A48-A50: the three-way drop matrix over I121, I122 and I123's chunked-write paragraph below
# them, where the advisor drop must leave I123 reporting MISPLACED rather than green.
#
# The validator runs IN PROCESS: every cell is `( vem_entry --arms <id> )` from the tree's copy, sourced
# once (see THE VALIDATOR RUNS IN PROCESS below); EQ holds that answer to the CLI's byte for byte, and
# its two CLI starts are the only ones left, declared in cells.decl.
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
# WHY BOTH DIRECTIONS ARE SEEDED. Every one of I108's
# three halves is absence-shaped: an extractor that stops matching compares empty to empty, a
# site scan that stops matching finds no sixth copy, and a population scan that stops matching
# leaves nothing to ask the reader about. All three silences read exactly like a conforming
# tree. So the battery seeds an offender for each half.
#
# EVERY SEED EDIT IS GUARDED BY `cmp -s`. An edit whose pattern stopped matching
# leaves a tree that is not an offender, and the assertion built on it would test a clean tree
# while printing the same line. An edit that does not apply is reported as FIXTURE BROKEN,
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

echo "HERMETIC-CONSUMED scripts/validate-enforcement-map.sh"

PRISTINE="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$PRISTINE" "$WORK"' EXIT

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

MUT_LIB="$D_ROOT/core/fixtures/lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found at $MUT_LIB" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
ARM="scripts/validate-enforcement-map.sh"
READER="core/scripts/validate-artifact-derivations.sh"
OKLINE="OK: enforcement-map.yaml in sync with gate-validation.md"

# ONE WORKING TREE, RESTORED BY THE PATHS A CASE TOUCHED. The tree is copied from the pristine
# seed ONCE; every case that used to build its own whole-tree copy (about fifty of them, each a
# cp -R of ~1400 files) now gets this tree back in its pristine state by restoring only the
# files it changed. Nothing a case does may bypass the record: every mutation goes through
# `edit`, and every plant, removal or created file calls `track <relative path>` BEFORE it
# writes, because a path that is not recorded is a path that leaks into the next case and reads
# as the next case's finding. Before the verdict the tree is restored once more and compared
# whole against the pristine seed (diff -rq); a difference is FIXTURE BROKEN, so an unrecorded
# write cannot pass unnoticed.
TREE="$WORK/t"
cp -R "$PRISTINE" "$TREE" || { echo "FIXTURE ERROR: cannot copy the seed" >&2; exit 2; }
TOUCHED="$WORK/touched"; : > "$TOUCHED"

# THE VALIDATOR RUNS IN PROCESS (BL-878). The tree's copy of validate-enforcement-map.sh is sourced ONCE,
# by absolute path, here in the shell that runs every cell: a source defines vem_entry and returns before
# any arm. Each cell is `( vem_entry --arms <id> )`. The two separate-program starts are the cli-pass and
# cli-refuse cells in EQ below, declared in this fixture's cells.decl.
. "$TREE/$ARM" || { echo "FIXTURE ERROR: sourcing $TREE/$ARM failed" >&2; exit 2; }
declare -F vem_entry >/dev/null || { echo "FIXTURE ERROR: $TREE/$ARM defined no vem_entry when sourced" >&2; exit 2; }

# track <relative path> — record a path about to be created, rewritten or removed. File-backed,
# because fresh runs in command substitutions where a shell variable would not survive.
track() { printf '%s\n' "$1" >> "$TOUCHED"; }

# fresh — the pristine tree. Restores each recorded path from the seed (or removes it, when the
# seed has no such file) and drops the now-empty directories a plant created. Never an edit
# that survives into a later case.
fresh() {
  local rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if [ -e "$PRISTINE/$rel" ]; then
      cp -p "$PRISTINE/$rel" "$TREE/$rel"
    else
      rm -f "$TREE/$rel"
      rmdir "$(dirname "$TREE/$rel")" 2>/dev/null
    fi
  done < "$TOUCHED"
  : > "$TOUCHED"
  printf '%s' "$TREE"
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
  track "$rel"
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
# other. A missing arm exits 2, which guard_sel reports as FIXTURE BROKEN. The run is the in-process
# entry sourced from $TREE above, so a tree other than $TREE is REFUSED with 2 rather than silently
# answered about $TREE.
run_arm() {
  [ -n "${2:-}" ] || { echo "run_arm called with no arm"; return 2; }
  [ "$1" = "$TREE" ] || { echo "run_arm called on $1, but the entry was sourced from $TREE"; return 2; }
  fx_inproc "$TREE/$ARM"
  ( vem_entry --arms "$2" ) 2>&1
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
  guard_sel "$rc" "$out" || return 1
  case "$out" in
    *"$want"*) ok "$label"; return 0 ;;
    *)         bad "$label — the arm did NOT report it (rc=$rc). The predicate no longer reaches this subject, and a corpus it cannot see reads exactly like a corpus with nothing wrong in it."; return 1 ;;
  esac
}

# --- The seed edit programs, one place each ------------------------------------
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

# THE TAUGHT FENCE INDENTED IN ONE COPY ONLY: a fork in LEADING BLANKS and nothing else. The
# reader still opens an indented fence, so half C is silent here by construction and no channel
# but half A's byte comparison can see it. It is seeded because nothing else seeds whitespace --
# every other case in this file changes a WORD.
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

# --- EQ: the in-process entry IS the CLI, byte for byte -----------------------
# Every cell below runs `( vem_entry --arms <id> )`; this proves that answer equals what
# `bash <validator> --arms <id>` prints, on stdout, on stderr and in the exit code, for each CLI
# outcome this fixture exercises: a pass (rc 0, the OK line) on the pristine tree and a refusal (rc 1,
# the fork finding) on A01's tree. The two inputs DIFFER, and that is asserted, so the comparison
# cannot pass by reading one tree twice. Run under this fixture's own `set -uo pipefail`. The two CLI
# starts are the cli-pass and cli-refuse rows of cells.decl; exit 2 is never exercised on purpose here
# (guard_sel treats it as FIXTURE BROKEN), so it has no twin.
eq_cmp() { # eq_cmp <cell> <arm> — on $TREE as it stands; leaves eq.<cell>.{io,ie,co,ce,ir,cr}
  local c="$1" a="$2" ir=0 cr=0
  fx_inproc "$TREE/$ARM"
  ( vem_entry --arms "$a" ) > "$WORK/eq.$c.io" 2> "$WORK/eq.$c.ie" || ir=$?
  FXCELL="$c" bash "$TREE/$ARM" --arms "$a" > "$WORK/eq.$c.co" 2> "$WORK/eq.$c.ce" || cr=$?
  echo "$ir" > "$WORK/eq.$c.ir"; echo "$cr" > "$WORK/eq.$c.cr"
}
eq_why=""
t="$(fresh)"
eq_cmp cli-pass I108
t="$(fresh)"
if edit "$t" "core/team-roles/sm.md" "$MUT_DRIFT"; then
  eq_cmp cli-refuse I108
  for c in cli-pass cli-refuse; do
    cmp -s "$WORK/eq.$c.io" "$WORK/eq.$c.co" || eq_why="$eq_why $c:stdout-differs"
    cmp -s "$WORK/eq.$c.ie" "$WORK/eq.$c.ce" || eq_why="$eq_why $c:stderr-differs"
    [ "$(cat "$WORK/eq.$c.ir")" = "$(cat "$WORK/eq.$c.cr")" ] \
      || eq_why="$eq_why $c:rc(in=$(cat "$WORK/eq.$c.ir"),cli=$(cat "$WORK/eq.$c.cr"))"
  done
  [ "$(cat "$WORK/eq.cli-pass.cr")" = 0 ] && grep -qF -- "$OKLINE" "$WORK/eq.cli-pass.co" || eq_why="$eq_why pass-not-rc0-with-OK-line"
  [ "$(cat "$WORK/eq.cli-refuse.cr")" = 1 ] && grep -qF -- "the taught derivation-fence passage has forked" "$WORK/eq.cli-refuse.co" "$WORK/eq.cli-refuse.ce" \
    || eq_why="$eq_why refuse-not-rc1-with-fork-finding"
  if cmp -s "$WORK/eq.cli-pass.co" "$WORK/eq.cli-refuse.co" && cmp -s "$WORK/eq.cli-pass.ce" "$WORK/eq.cli-refuse.ce"; then
    eq_why="$eq_why the-two-inputs-gave-identical-output"
  fi
  if [ -z "$eq_why" ]; then
    ok "EQ the in-process entry equals bash <validator> --arms I108 byte for byte (stdout, stderr, rc) on a pass (rc 0) and a refusal (rc 1) whose outputs differ"
  else
    bad "EQ the in-process entry differs from the CLI:$eq_why"
  fi
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
track core/team-roles/zz-newrole.md
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
  track "$rel"
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

# --- Assertion 8: a body drift on A01's tree ----------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/sm.md" "$MUT_DRIFT"; then
  says I108 "A08a an offender: the arm reports the body drift" \
       "$t" "the taught derivation-fence passage has forked"
fi

# --- Assertion 9: a drift in tea.md --------------------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/tea.md" "$MUT_DRIFT"; then
  says I108 "A09a an offender: the arm reports the drift in tea.md" \
       "$t" "the taught derivation-fence passage has forked"
fi

# --- Assertion 10: remediator.md's fence renamed -------------------------------
# Built on A05's tree.
t="$(fresh)"
if edit "$t" "core/team-roles/remediator.md" "$MUT_TEMPLATE"; then
  says I108 "A10a an offender: the arm names remediator.md" \
       "$t" "core/team-roles/remediator.md"
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

# --- Assertion 12: A11's tree again --------------------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/analyst.md" "$MUT_INDENT"; then
  says I108 "A12a an offender: the arm reports the leading-blank fork" \
       "$t" "the taught derivation-fence passage has forked"
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

# --- Assertion 14: A13's tree again --------------------------------------------
t="$(fresh)"
brk=0
for r in $FIVE; do
  edit "$t" "core/team-roles/$r.md" "$MUT_UNCLOSED" || { brk=1; break; }
done
if [ "$brk" -eq 0 ]; then
  says I108 "A14a an offender: the arm reports the unclosed block" \
       "$t" "open a derivation fence the reader never sees CLOSED"
fi

# --- Assertion 15: the reader is ABSENT ---------------------------------------
# The dedicated refusal must be the message that fires, and the probe's must not: measured on
# an earlier cut of this arm, the file test sat INSIDE the corpus block, the probe's own guard
# left its reader output empty, and the refusal the header cited as evidence appeared zero
# times while the probe's appeared once. Halves A and B must also still run — a deleted reader
# must not hide a forked passage — so the fork is seeded in the same tree.
t="$(fresh)"
track "$READER"
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
# presence-shaped: each demands the specific message that names it.
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
I121_MISSING="do not carry the verify-shape paragraph"
I121_INLINE="opener sentence appears inside another line or paragraph in"
I121_FORK="the verify-shape paragraph has forked"
I121_EXTRA="outside core/team-roles/*.md carry the verify-shape opener sentence"
I121_PTRMSG="tells the teammate to run scripts/ai-dlc/validate-derivations.sh"

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
track core/skills/zz-planted.md
mkdir -p "$t/core/skills"
printf 'See the role contract.\n\n%s Do it.\n' "$OPENER2" > "$t/core/skills/zz-planted.md"
if grep -qF -- "$OPENER2" "$t/core/skills/zz-planted.md"; then
  says I121 "A26 half B  a copy of the opener under core/skills/ is REPORTED" \
       "$t" "$I121_EXTRA: core/skills/zz-planted.md"
else
  bad "FIXTURE BROKEN — the core/skills/ copy was not written, so A26 tested a clean tree"
fi
t="$(fresh)"
track core/fixtures/zz-planted/x.md
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
track core/team-roles/zz-newrole.md
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

# --- A31a-A33a: offender trees ---------------------------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/dev.md" "$MUT_I121_PTR"; then
  says I121 "A31a an offender: the arm reports the deleted pointer" "$t" "$I121_FORK"
fi
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I121_DROP"; then
  says I121 "A32a an offender: the arm names qa.md" "$t" "$I121_MISSING: core/team-roles/qa.md"
fi
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I121_INLINE"; then
  says I121 "A33a an offender: the arm reports the inline opener" "$t" "$I121_INLINE: core/team-roles/qa.md"
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
I122_MISSING="do not carry the advisor paragraph"
I122_INLINE="advisor opener sentence appears inside another line or paragraph in"
I122_FORK="the advisor paragraph has forked"
I122_EXTRA="outside core/team-roles/*.md carry the advisor opener sentence"

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
track core/skills/zz-planted.md
mkdir -p "$t/core/skills"
printf 'See the role contract.\n\n%s Do it.\n' "$OPENER3" > "$t/core/skills/zz-planted.md"
if grep -qF -- "$OPENER3" "$t/core/skills/zz-planted.md"; then
  says I122 "A39 half B  a copy of the advisor opener under core/skills/ is REPORTED" \
       "$t" "$I122_EXTRA: core/skills/zz-planted.md"
else
  bad "FIXTURE BROKEN — the core/skills/ copy was not written, so A39 tested a clean tree"
fi
t="$(fresh)"
track core/fixtures/zz-planted/x.md
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
track core/team-roles/zz-newrole.md
printf '# Role: Planted\n\n## Identity\n\nA role added after this arm was written.\n' > "$t/core/team-roles/zz-newrole.md"
says I122 "A41 half A  a NEW role file without the advisor paragraph is REPORTED (the population is the glob, not a list)" \
     "$t" "$I122_MISSING: core/team-roles/zz-newrole.md"

# --- A43a-A45a: offender trees ---------------------------------------------------
t="$(fresh)"
if edit "$t" "core/team-roles/dev.md" "$MUT_I122_WORD"; then
  says I122 "A43a an offender: the arm reports the dropped touchpoint" "$t" "$I122_FORK"
fi
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I122_DROP"; then
  says I122 "A44a an offender: the arm names qa.md" "$t" "$I122_MISSING: core/team-roles/qa.md"
fi
t="$(fresh)"
if edit "$t" "core/team-roles/qa.md" "$MUT_I122_INLINE"; then
  says I122 "A45a an offender: the arm reports the inline opener" "$t" "$I122_INLINE: core/team-roles/qa.md"
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
run_i75() { run_arm "$1" I75; }
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

# --- I75 on REAL-SIZED spans (BL-1000) -----------------------------------------
# The fails-closed token was read from the whole span between the markers. merge-review-shards.sh's
# span is ~1390 lines and carries the token on ten of them, so deleting its one real guard line left
# I75 green; a start marker with no end marker ran the span to EOF. Both seeds are the real files.
# i75_says <label> <tree> <want-substring> <subject basename> -- the finding must name that subject.
i75_says() {
  local label="$1" t="$2" want="$3" subj="$4" out rc
  out="$(run_i75 "$t")"; rc=$?
  if guard_sel "$rc" "$out"; then
    case "$out" in
      *"$want"*"$subj"*) ok "$label" ;;
      *) bad "$label -- I75 did not report $subj (rc=$rc): $(printf '%s\n' "$out" | grep I75 | cut -c1-200)" ;;
    esac
  fi
}

# A51: merge-review-shards.sh's terminal guard `exit 2` removed -- the line AFTER the cwd walk.
# (Its own self-probe, which builds the real-sized copies from this file, refuses too; the arm
# reads the corpus finding, which names the subject.)
t="$(fresh)"
if edit "$t" "core/scripts/merge-review-shards.sh" '
  /^# --- AI_DLC_ROOT ---/ { inb = 1 }
  inb && /ai_dlc_resolve_root "\$\(pwd\)"/ { w = 1 }
  inb && w && $0 == "  exit 2" { next }
  /^# --- end AI_DLC_ROOT ---/ { inb = 0 }
  { print }'; then
  i75_says "A51 I75 a REAL-SIZED span (merge-review-shards.sh, ~1390 lines) with its terminal guard deleted is REPORTED as not failing closed, though nine other token lines remain in its span" \
    "$t" "does not fail closed" "merge-review-shards.sh"
fi

# A52: audit-layer-debt.sh's end marker removed -- the span runs to EOF, past its register guard.
t="$(fresh)"
if edit "$t" "core/scripts/audit-layer-debt.sh" '
  /^# --- end AI_DLC_ROOT ---/ { next }
  { print }'; then
  i75_says "A52 I75 a start marker with NO end marker (audit-layer-debt.sh, span to EOF) is REPORTED by name" \
    "$t" "has NO end marker" "audit-layer-debt.sh"
fi

# --- Verdict ------------------------------------------------------------------
# THE COUNT IS ASSERTED. A driver whose `for` loop or `if` guard stopped reaching an assertion
# prints fewer lines and no failure, and an unrun assertion is indistinguishable from one that
# passed.
EXPECTED=55
tree_clean() { fresh >/dev/null; diff -rq "$PRISTINE" "$TREE" >"$WORK/tree.diff" 2>&1; }
# PROBE of the guard, both directions: a write that was never recorded must be seen, and once it is
# gone the same guard must be quiet. A guard that cannot fail reads exactly like one that passed.
printf x > "$TREE/core/zz-unrecorded.probe"
if tree_clean; then probe_seen=0; else probe_seen=1; fi
rm -f "$TREE/core/zz-unrecorded.probe"
if tree_clean; then probe_quiet=1; else probe_quiet=0; fi
if [ "$probe_seen" = 1 ] && [ "$probe_quiet" = 1 ]; then
  ok "D-tree the restore guard reports an unrecorded write (FIXTURE BROKEN) and is quiet once it is removed"
else
  bad "D-tree the restore guard cannot tell an unrecorded write from a clean tree -- seen=$probe_seen quiet=$probe_quiet"
fi
if ! tree_clean; then
  printf '\nderived-fence-binding: FIXTURE BROKEN — the working tree differs from the pristine seed after the final restore, so some case wrote a path it never recorded with track:\n' >&2
  head -5 "$WORK/tree.diff" >&2
  exit 2
fi
report_end derived-fence-binding "$EXPECTED"
