#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# self-update-fixture-log — assert step 2's fixture run leaves evidence behind, and that its
# COVERAGE join refuses a slice that omits a fixture the pull itself changes.
#
# THE LOAD-BEARING ASSERTION IS PART 3: the failing fixture's own output must still be
# readable AFTER the tree it ran in has been deleted. That is the whole defect this runner
# closes — step 2 discards the branch and restores the tree on red, so a run whose output
# lived only in the operating agent's context left the next operator with "the self-update
# failed" and nothing else. It happened twice on the reference consumer.
#
# Parts 4 and 5 are the other half, and they are not decoration: a runner that exits 0 when
# it ran nothing turns an empty set into a green suite, which is the failure mode this repo
# names "a zero is not a finding". A green run and a run that never happened must not be the
# same exit code.
#
# PARTS 7-12 COVER THE `base..theirs` COVERAGE JOIN, and they are why this fixture now builds
# a THROWAWAY DISTRIBUTION REPO. The join resolves both refs and derives the diff, so the
# literal `base-sha` / `theirs-ref` strings this fixture used to pass now stop every run at
# the unresolvable arm before it asserts anything about the log. The repo is shaped so ONE
# range carries all four coverage cases at once — an offender, a NAMED near-miss, a
# `.dist-only` exemption and a deleted-upstream exemption — because a near-miss standing in a
# SEPARATE run only asks whether the arm fires, never whether it fires on the right directory.
#
# TWO GUARDS SIT ON THE SAME PATH AND ONE COVERS THE OTHER, so the seeds are chosen to split
# them. A bogus ref is refused by the ref-resolution loop AND, with that loop removed, by the
# diff-failure arm below it — same exit code either way. The input only the FIRST can see is
# a sha that names a TREE: it cannot be peeled to a commit, and `git diff <tree> <commit>`
# succeeds, so with the ref loop neutered the join runs against a base that never resolved
# and reports green. Part 12 is that input, and it is what the ref-loop mutant dies on.
#
#
# THE MUTATION BATTERY IS `self-update-fixture-log-mutants`, distribution-only. It mutates copies
# of core's own `self-update-fixtures.sh`, which a consumer is denied editing, so proving each arm
# here can fail is a question about a file only this repository changes; a consumer keeps every
# behavioural arm and loses only that proof. Both fixtures source `lib.sh` beside this file, so a
# mutant is driven against the same worlds and read by the same log readers as the arms below.
# The verdict/record join's own probe and its SKILL.md mutants (J1-J14) stay here: they are cheap
# text reads, and their subject is a file a consumer holds.
# Usage: run.sh [path-to-self-update-fixtures.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = the harness could not run.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before reading anything (I10). Part 14 names
# AI_DLC_GATE_IN_SAFE_STOP, the key gate_record_open() reads, so without this the arm
# asserts against whatever the developer's settings.json happens to say.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="self-update-fixture-log"
SUFL_RUNNER_ARG="${1:-}"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; no world exists to assert against" >&2; exit 2; }
# shellcheck source=lib.sh
. "$HERE/lib.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh"

# --- Part 0: the seed can EXPRESS the defect ----------------------------------------------
# A fixture whose tree cannot reach the branch under test proves nothing, and every arm below
# would report green over a range the join never had anything to say about.
DIFFSET="$(G diff --name-only "$D_BASE" theirs-tag -- core/fixtures/ 2>/dev/null \
            | sed -E 's#^core/fixtures/([^/]+)/.*#\1#' | sort -u | tr '\n' ',')"
QUIETSET="$(G diff --name-only "$D_THEIRS" "$D_QUIET" -- core/fixtures/ 2>/dev/null | tr -d '\n')"
SHIPSET="$(G diff --name-only "$D_QUIET" "$D_SHIP" -- core/fixtures/ 2>/dev/null \
            | sed -E 's#^core/fixtures/([^/]+)/.*#\1#' | sort -u | tr '\n' ',')"
if [ "$DIFFSET" = "touched-deleted,touched-distonly,touched-named,touched-shippable," ] \
   && [ -z "$QUIETSET" ] && [ "$SHIPSET" = "touched-shippable," ] \
   && [ -n "$D_TREE" ] && [ -n "$D_BASE" ] && [ "$D_BASE" != "$D_THEIRS" ]; then
  ok "SEED: base..theirs carries all four coverage cases, the quiet range carries none, and the ship range carries one with no exemption in it"
else
  bad "FIXTURE ERROR: the seeded distribution does not present the coverage cases (base..theirs gave '${DIFFSET}', the quiet range gave '${QUIETSET:-empty}', the ship range gave '${SHIPSET:-empty}', tree '${D_TREE:-none}'). Every assertion below would be taken over a range the join cannot reach"
fi

# The wrong-repo seed has to be wrong in ONE readable way. If `core/fixtures` were absent at
# base and off disk too, Part 13 would fire for a guard reading any of the three, and the arm
# would not be able to say which read it is asserting.
if ! W cat-file -e "${W_THEIRS}:core/fixtures" 2>/dev/null \
   && W cat-file -e "${W_BASE}:core/fixtures" 2>/dev/null \
   && [ -f "$WREPO/core/fixtures/touched-shippable/run.sh" ] && [ -n "$W_BASE" ]; then
  ok "SEED: the wrong-repo checkout has core/fixtures at BASE and on DISK but not at THEIRS — only a read at theirs can refuse it"
else
  bad "FIXTURE ERROR: the wrong-repo seed is not shaped to discriminate (theirs-tree present, or base tree and worktree copy absent). Part 13 would fire for a guard reading the base ref or the working directory, and could not tell them apart"
fi

# The over-completeness seed has to disagree with itself, and one equality carries all of it.
# Six probes, each scored `<at-theirs><on-disk>`. Four of them are the discriminating pairs; the
# last two are the directories Parts 14 and 15 use, asserted to AGREE so that a disk-reading
# implementation moves Part 17 and leaves those two alone. Without this arm a seed whose disk
# state had drifted back into agreement would leave Part 17 passing for either implementation.
DISKSET=""
for probe in theirs-only-distonly/.dist-only theirs-only-nodriver/run.sh \
             disk-only-distonly/.dist-only disk-missing-driver/run.sh \
             named-distonly/.dist-only touched-deleted/run.sh; do
  pt=n; pd=n
  G cat-file -e "${D_QUIET}:core/fixtures/${probe}" 2>/dev/null && pt=y
  [ -e "$DIST/core/fixtures/${probe}" ] && pd=y
  DISKSET="${DISKSET}${probe}:${pt}${pd},"
done
if [ "$DISKSET" = "theirs-only-distonly/.dist-only:yn,theirs-only-nodriver/run.sh:ny,disk-only-distonly/.dist-only:ny,disk-missing-driver/run.sh:yn,named-distonly/.dist-only:yy,touched-deleted/run.sh:nn," ]; then
  ok "SEED: four directories disagree between the theirs tree and the DIST worktree, in both directions for both probes, and Parts 14 and 15's own directories agree"
else
  bad "FIXTURE ERROR: the disk/theirs disagreement seed reads '${DISKSET:-empty}'. Where disk and theirs agree, a probe reading the checkout and a probe reading the ref are the same program, and Part 17 would pass for either"
fi

# --- Part 1: an all-green run exits 0 and still writes the log --------------------------
# The log is not a failure artifact. A green self-update that is later questioned needs the
# same record, and a runner that wrote only on red would have none.
rm -f "$LOGDIR"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS" green-one cwd-probe >/dev/null 2>&1
rc=$?
L="$(newest_log)"
if [ "$rc" -eq 0 ] && [ -n "$L" ] && [ -s "$L" ]; then
  ok "an all-green run exits 0 and writes a non-empty log"
else
  bad "all-green run: expected rc=0 with a non-empty log, got rc=$rc log='${L:-none}'"
fi

# --- Part 2: the fixture runs from the CONSUMER ROOT ------------------------------------
if [ -n "$L" ] && grep -qF "cwd-probe ran from: $CONS" "$L"; then
  ok "the fixture is run with the consumer root current — the same directory both pre-push hooks use"
else
  bad "the fixture did not run from the consumer root. A fixture whose verdict depends on the caller's directory has shipped before (v0.263.0), so the runner deciding a self-update must stand where the gate deciding a push stands"
fi

# --- Part 3: THE DECISIVE ONE — the output outlives the tree ----------------------------
# Run a red fixture, then destroy the fixture tree exactly as step 2 does on red, and require
# the failing output to still be readable. The log is written to _bmad-output/, which the
# branch discard does not touch; a runner that buffered and wrote at exit would pass Parts 1
# and 2 and fail here, and so would one that wrote into the tree it is about to lose.
rm -f "$LOGDIR"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS" green-one red-one >/dev/null 2>&1
rc=$?
L="$(newest_log)"
rm -rf "$CONS/tests"          # the branch discard, in one line
if [ "$rc" -ne 0 ] && [ -n "$L" ] && grep -qF "THE DECISIVE LINE the operator needs after the branch is gone" "$L"; then
  ok "a red run exits non-zero and its failing output survives the tree being destroyed"
else
  bad "a red run left nothing readable after the tree was discarded (rc=$rc). That is the whole defect: the record died with the branch"
fi
if [ -n "$L" ] && grep -qF "red-one: and a stderr line too" "$L"; then
  ok "stderr is captured too — a fixture that reports its failure on stderr is the common case"
else
  bad "the log captured stdout only; a fixture failing on stderr would leave a log that reads clean"
fi
if [ -n "$L" ] && grep -qF "green-one: every assertion held" "$L"; then
  ok "the green fixture's output is in the same log — the reader can see what DID pass alongside what did not"
else
  bad "only the failing fixture was logged; without the passing ones the reader cannot tell a broken slice from a broken harness"
fi

# --- Part 4: an EMPTY set must not read as green ----------------------------------------
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS" >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "naming no fixtures exits 2, not 0 — 'no failures' and 'no assertions' are not the same answer"
else
  bad "naming no fixtures did not exit 2. An empty set reporting green is how a self-update ships having verified nothing"
fi

# --- Part 5: a named fixture with no driver is not a pass -------------------------------
# The derived set comes from the distribution; if the slice did not write one of them, that is
# a finding about the CYCLE. Counting it green is how a missing file becomes a silent skip.
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS" never-written-by-the-slice >/dev/null 2>&1
rc=$?
L5="$(newest_log)"
if [ "$rc" -ne 0 ] && [ -n "$L5" ] && grep -qF "MISSING: tests/fixtures/never-written-by-the-slice/run.sh" "$L5"; then
  ok "a named fixture whose driver the slice never wrote is not counted as a pass, and the log says which one"
else
  bad "a named fixture with no run.sh scored as green (rc=$rc), or the log did not name it — a slice that wrote nothing would report a clean suite"
fi

# --- Part 6: the log extension is one git can still show ---------------------------------
# A reference consumer's .gitignore carries `*.log` and `*.txt`. Either would produce an
# artifact that exists on disk and is invisible to every `git status` the operator reads.
if [ -n "$L" ] && case "$L" in *.md) true ;; *) false ;; esac; then
  ok "the log is written as .md — not an extension a consumer's .gitignore commonly swallows"
else
  bad "the log is '${L:-none}'. A .log or .txt artifact is on disk and absent from git status, which is how evidence goes missing twice"
fi

# --- Part 7: the COVERAGE join refuses an INCOMPLETE set, and only for the right directory -
# ONE run, four cases. `touched-shippable` is changed by the diff, shippable and omitted — the
# offender. Standing beside it in the SAME run: `touched-named`, changed and NAMED;
# `touched-distonly`, changed and carrying the marker at theirs; `touched-deleted`, whose
# run.sh the diff removes; and `untouched-one`, which the diff never touches. All four are
# omitted from the named set, and none of them may appear in the refusal.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
OUT7="$CONS2/out-part7.txt"; ERR7="$CONS2/err-part7.txt"
bash "$RUNNER" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >"$OUT7" 2>"$ERR7"
rc=$?
L7="$(newest_log2)"
COV7="$(cov_set "$L7")"
if [ "$rc" -eq 2 ] && grep -qF "the slice omits fixtures this diff CHANGES:" "$ERR7" \
   && grep -qF "touched-shippable" "$ERR7"; then
  ok "a diff-touched shippable fixture the slice omits is refused with exit 2 and named on stderr"
else
  bad "the slice omitted 'touched-shippable', which base..theirs changes, and the runner did not refuse (rc=$rc). Step 2's grep term cannot see a fixture the pull REPAIRS, so this join is the only thing between that slice and a consumer pre-push that stays red"
fi
if [ "$COV7" = "touched-shippable," ]; then
  ok "the logged refusal is EXACTLY the omitted shippable fixture — the named, the .dist-only, the deleted and the untouched directory all stood down in the same run"
else
  bad "the logged refusal is '${COV7:-empty}', not 'touched-shippable,'. Anything extra is an exemption that stopped exempting; anything missing is the join failing to see its own subject — and both are decided in this one run, so neither can be an artefact of a separate invocation"
fi
# ORDERING, on both channels in one arm. They are one property — nothing ran before the
# refusal — and splitting them would give a single placement change two cells to move.
if [ "$rc" -eq 2 ] && [ -n "$L7" ] && grep -qF "COVERAGE: the diff changes" "$L7" \
   && ! grep -qF "===== FIXTURE " "$L7" && ! grep -qE '^ +(ok|FAIL|MISS) +' "$OUT7"; then
  ok "the refusal is ORDERED BEFORE the fixture loop — no per-fixture section in the log and no per-fixture verdict on stdout"
else
  bad "the refusal was reported after the loop had already run: log sections $(grep -cF '===== FIXTURE ' "$L7" 2>/dev/null), stdout verdicts $(grep -cE '^ +(ok|FAIL|MISS) +' "$OUT7" 2>/dev/null). An incomplete set that prints a plausible green above its own finding is the state this arm exists to refuse, and an operator reads whichever channel is in front of them"
fi

# --- Part 8: naming the diff-touched fixture clears the join ------------------------------
# The positive direction, and it is what stops Part 7 from passing for a join that refuses
# everything. It runs over the SHIP range, whose diff carries one fixture and no exempt
# directory at all: over base..theirs a mutation to an exemption would fail this arm as well
# as Part 7's, and two arms moving on one edit means one of them is watching the other.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_QUIET" "$D_SHIP" "$CONS2" touched-shippable green-one \
  >"$CONS2/out-part8.txt" 2>"$CONS2/err-part8.txt"
rc=$?
L8="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$L8" ] && grep -qF "===== FIXTURE touched-shippable =====" "$L8" \
   && grep -qF "===== FIXTURE green-one =====" "$L8" && ! grep -qF "COVERAGE:" "$L8"; then
  ok "naming the fixture the diff changes clears the join: the run reaches the loop and exits 0"
else
  bad "naming the one diff-touched fixture did not produce a green run (rc=$rc). A join that refuses a correct slice wedges every self-update, which is worse than the gap it closes"
fi

# --- Part 9: a range that touches no fixture is not a refusal -----------------------------
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" green-one \
  >"$CONS2/out-part9.txt" 2>"$CONS2/err-part9.txt"
rc=$?
L9="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$L9" ] && grep -qF "===== FIXTURE green-one =====" "$L9" \
   && ! grep -qF "COVERAGE:" "$L9"; then
  ok "a range whose only change is a machinery path leaves every fixture unnamed and unrefused"
else
  bad "a range touching no fixture at all produced a coverage finding or a non-zero exit (rc=$rc). The pathspec is what bounds this join, and a join that fires on a machinery-only pull refuses every one of them"
fi

# --- Parts 10 and 11: an unresolvable ref is exit 2, never a silent skip -------------------
# BOTH positions, because the resolution loop walks BASE and THEIRS and a guard that reads
# only the first answers correctly for the input a one-sided test supplies. The assertion
# keys on the ref-resolution message specifically: the diff-failure arm below it also exits 2
# on a bogus ref, so an arm keyed on the exit code alone cannot tell the two apart.
#
# It does NOT re-assert that nothing ran first. Part 7 owns the ordering of this block, and a
# placement change would otherwise move four cells for one edit.
p_unresolvable() { # $1=label $2=base $3=theirs $4=the ref that must be named
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$RUNNER" "$DIST" "$2" "$3" "$CONS2" green-one >/dev/null 2>"$CONS2/err-unres.txt"
  local r=$? lg; lg="$(newest_log2)"
  if [ "$r" -eq 2 ] && [ -n "$lg" ] \
     && grep -qF "COVERAGE: UNRESOLVABLE — '${4}' does not name a commit" "$lg"; then
    ok "$1"
  else
    bad "$1 — got rc=$r and a log that does not record '${4}' as unresolvable. A coverage check that did not run reads exactly like one that passed, and it must not be the fixture loop's job to notice"
  fi
}
p_unresolvable "an unresolvable BASE exits 2 and logs COVERAGE: UNRESOLVABLE naming that ref" \
               no-such-base-ref theirs-tag no-such-base-ref
p_unresolvable "an unresolvable THEIRS exits 2 and logs it too — the loop reads both positions" \
               "$D_BASE" no-such-theirs-ref no-such-theirs-ref

# --- Part 12: a ref that resolves to a TREE is still unresolvable --------------------------
# The input only the ref-resolution loop can see. `git diff <tree> <commit>` SUCCEEDS, so the
# diff-failure arm never fires here; without the peel to `^{commit}` the join would run
# against a base that names no commit and report green over whatever fell out.
p_unresolvable "a BASE naming a TREE rather than a commit is refused — the one input the diff-failure arm below cannot catch" \
               "$D_TREE" theirs-tag "$D_TREE"

# --- Part 13: a git repo that is NOT the distribution is refused --------------------------
# Both refs resolve and `git diff` succeeds, so neither arm above sees this. What comes back
# is an EMPTY diff, which walks the join to its own success: nothing uncovered, nothing said,
# a pass that is byte-identical to a complete set. Naming a fixture that WOULD run green is
# deliberate — the failure this refuses is a green suite, so the arm has to be able to see one.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one \
  >"$CONS2/out-part13.txt" 2>"$CONS2/err-part13.txt"
rc=$?
L13="$(newest_log2)"
if [ "$rc" -eq 2 ] && [ -n "$L13" ] && grep -qF "COVERAGE: WRONG-REPO" "$L13" \
   && grep -qF "has no core/fixtures tree" "$CONS2/err-part13.txt"; then
  ok "a \$DIST that is a git repo but carries no core/fixtures at theirs is refused with exit 2 and COVERAGE: WRONG-REPO"
else
  bad "a \$DIST with no core/fixtures at theirs was accepted (rc=$rc). Its diff is EMPTY, so the join reports nothing having OBSERVED nothing — and this fixture's own resolver reaches that state, because walking up four levels from a consumer-layout copy of the runner lands on the consumer root"
fi
# The near-miss, in the SAME repo with ONE argument different: swap the refs and theirs now
# carries the tree. An arm that fired here as well would be refusing the repo, not the read.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$WREPO" "$W_THEIRS" "$W_BASE" "$CONS2" touched-shippable \
  >"$CONS2/out-part13b.txt" 2>"$CONS2/err-part13b.txt"
rc=$?
L13B="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$L13B" ] && grep -qF "===== FIXTURE touched-shippable =====" "$L13B" \
   && ! grep -qF "COVERAGE:" "$L13B"; then
  ok "the same checkout with the refs swapped is NOT refused — the tree is read at THEIRS, not at base and not off disk"
else
  bad "the same checkout was refused with the refs swapped (rc=$rc), so the guard is keyed on something other than the theirs position. core/fixtures is committed at that end of this range"
fi

# --- Parts 14 to 19: the OVER-completeness arm ---------------------------------------------
# The join above refuses a set that OMITS a diff-touched directory. These refuse a set that
# CONTAINS one no consumer can ever hold. Filed by the reference consumer as
# PC-S307-STEP-2-FIXTURE-TERM-B-EXCLUSIONS-ARE-DERIVABLE-BY-HAND-AND-WERE-MIS-DERIVED: a hand
# derivation of step 2's term B yielded `backlog-size-ceiling`, which carries `.dist-only`, and
# it was written into the consumer's `tests/fixtures/` as a RETIRED-FIXTURE-ORPHAN. The run was
# GREEN — the slice delivered what was named, so the MISS arm had nothing to say.
#
# ALL OF THESE RUN OVER THE QUIET RANGE, whose diff touches no fixture at all. That is what
# makes a refusal here unambiguous: the miss-join has nothing to report over that range, so any
# COVERAGE finding is this arm's, and a mutation to one arm cannot be scored by the other.
#
# WHICH ARM OWNS WHICH MUTATION, measured by running THIS WHOLE FIXTURE against each of Mutants
# 6 to 14 as its subject rather than by reading the scoring blocks below. Most of them move more
# than one arm, and that is reported here rather than engineered away: the overlaps are
# conservation rather than vacuity, because a wrong implementation of a two-probe guard is wrong
# in several ways at once. No arm here may be deleted on the grounds that another also catches
# its mutant.
#   14  ordering, the reason text, and the exit code       shares every mutant with 15 or 17
#   15  the deleted-driver exclusion, under its own reason shares every mutant with 14 or 17
#   16  the ACQUITTAL of a wholly shippable set            the arm Mutant 14 is scored on, and
#                                                          the only one a WIDENING copy fails
#   17  the read is at THEIRS, not off the checkout        Mutant 11 moves THIS ARM ALONE
#   18  sited below the ref-resolution loop                Mutant 9
#   19  sited below the wrong-repo guard                   Mutant 10, which Part 18 cannot see
# Mutants 9 and 10 also move Parts 11 and 13. That is the same property read from the other
# side — an arm hoisted above a guard makes that guard unreachable — not a second subject.

# --- Part 14: the .dist-only offender, convicted BESIDE three legitimate directories ---------
# ONE run, four directories. A near-miss in a SEPARATE run is an ADJACENT input: it can only ask
# whether the arm fires, never whether it fires on the right directory, and this repo has paid
# three rounds for that shape already. The set equality is the whole assertion — `named-distonly`
# present is the conviction, the other three absent is the acquittal, and both are decided by the
# same invocation over the same tree.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
OUT14="$CONS2/out-part14.txt"; ERR14="$CONS2/err-part14.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     named-distonly green-one cwd-probe touched-shippable >"$OUT14" 2>"$ERR14"
rc=$?
L14="$(newest_log2)"
UNS14="$(uns_set "$L14")"
if [ "$rc" -eq 2 ] && grep -qF "the named set contains fixtures no consumer can run:" "$ERR14"; then
  ok "a named directory carrying .dist-only at theirs is refused with exit 2 and the arm's own message"
else
  bad "the named set contained 'named-distonly', which carries .dist-only at theirs, and the runner did not refuse with that message (rc=$rc). Step 2 derives this set by hand; the exclusions were stated for the diff-side term only, and the surplus directory reaches the consumer as a fixture core never ships"
fi
if [ "$UNS14" = "named-distonly," ]; then
  ok "the logged refusal is EXACTLY the unshippable directory — the three legitimate names beside it in the SAME run were all acquitted"
else
  bad "the logged refusal is '${UNS14:-empty}', not 'named-distonly,'. Anything extra is the arm convicting a directory a consumer can perfectly well run, which wedges every self-update; anything missing is the arm failing to see its own subject. Both are decided here, so neither can be an artefact of a separate invocation"
fi
if grep -qF "carries .dist-only at" "$ERR14"; then
  ok "the refusal states WHICH exclusion it applied, so an operator can tell a never-shipped fixture from a deleted driver"
else
  bad "the refusal named the directory without its reason. Two exclusions produce this exit and a remedy that cannot say which one applied sends the reader to the wrong half of step 2"
fi
# ORDERING, both channels in one arm — they are one property and splitting them would give a
# single placement change two cells to move.
if [ "$rc" -eq 2 ] && [ -n "$L14" ] && ! grep -qF "===== FIXTURE " "$L14" \
   && ! grep -qE '^ +(ok|FAIL|MISS) +' "$OUT14"; then
  ok "the refusal is ORDERED BEFORE the fixture loop — no per-fixture section in the log and no per-fixture verdict on stdout"
else
  bad "the refusal was reported after the loop had already run: log sections $(grep -cF '===== FIXTURE ' "$L14" 2>/dev/null), stdout verdicts $(grep -cE '^ +(ok|FAIL|MISS) +' "$OUT14" 2>/dev/null). Running the surplus fixture first is how the orphan gets a green verdict printed above the finding that condemns it"
fi

# --- Part 15: the deleted-driver offender, in its own run and with its own reason ------------
# The SECOND exclusion, and it needs its own run rather than a second offender in Part 14's: a
# mutant that deletes one probe and keeps the other must move exactly one of these two arms.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR15="$CONS2/err-part15.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     touched-deleted green-one cwd-probe touched-shippable \
     >"$CONS2/out-part15.txt" 2>"$ERR15"
rc=$?
UNS15="$(uns_set "$(newest_log2)")"
if [ "$rc" -eq 2 ] && [ "$UNS15" = "touched-deleted," ] && grep -qF "no run.sh at" "$ERR15"; then
  ok "a named directory whose driver upstream DELETED is refused, named alone, and reported under the deleted-driver reason"
else
  bad "a named directory with no run.sh at theirs was not refused under its own reason (rc=$rc, refused '${UNS15:-empty}'). The MISS arm below reports this only when the slice FAILED to write the directory; when the slice writes it the run is green and the orphan survives, which is the episode that was filed"
fi

# --- Part 15b: an UNPARSABLE argument is not a deleted driver ---------------------------------
# PC-S310. Under zsh an unquoted `$FIX` holding a newline-joined list does not word-split, so a
# whole list arrives as ONE argument and every name in it is convicted with a sentence asserting
# that upstream deleted the driver — a fact about the distribution that is false, naming a cause
# the operator cannot act on, and prescribing a remedy (drop it from the slice) that the
# diff-side join then refuses as an omission.
#
# THE DISCRIMINATOR IS THE ARGUMENT'S SHAPE, AND A TREE PROBE IS NOT IT. The first cut of the
# fix probed `${THEIRS}:core/fixtures/${d}` and ordered it first, on the reasoning that a
# retirement resolves as a tree and a bad argument does not. That is FALSE for the case this
# fixture already seeds: `touched-deleted` has the whole directory removed at theirs, so it
# resolves to no tree either, and Part 15 went red — the tree probe relabels every real
# retirement. A fixture name cannot contain a space or a `/`; that is what separates them.
#
# TWO ARMS, because one alone cannot tell a working discriminator from a blanket relabel:
# the joined argument must get the NEW row, and `touched-deleted` must keep the OLD one. Part
# 15 above is the second half and is left where it is.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR15B="$CONS2/err-part15b.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     "touched-shippable green-one" cwd-probe \
     >"$CONS2/out-part15b.txt" 2>"$ERR15B"
rc=$?
# KEYED ON THE EMITTED ROW, NEVER ON THE TOKEN ANYWHERE IN THE OUTPUT. The remedy paragraph
# below the rows names the 'not a fixture NAME' case UNCONDITIONALLY, on every refusal — so a
# bare `grep -qF` for that phrase passes on a run that emitted no such row at all. Measured on
# this branch before it was fixed: seeding only a genuine retirement produced the deleted-driver
# row and the first conjunct still passed. That is `verification-discipline.md`'s "bind to the
# line that EMITS the thing", and it was committed here in the same branch that FILED it as
# BL-227. A row opens a line, carries the subject, and is indented two spaces.
if [ "$rc" -eq 2 ] && grep -qE '^  touched-shippable green-one — not a fixture NAME' "$ERR15B" \
   && ! grep -qE '^  [^ ].* — no run\.sh at' "$ERR15B"; then
  ok "a joined-list argument is refused as an unparsable NAME, not as a deleted driver — the operator is sent to the argument rather than to a retirement that never happened"
else
  bad "a joined-list argument was not refused under its own reason (rc=$rc). Either it is being convicted as a deleted driver — the filed defect, which sends the operator to a remedy that walks into the opposite refusal — or the arm no longer fires at all"
fi

# THE SAME JOINED LIST WRITTEN IN THE PATH FORM, AND IT IS THE ACQUITTING DIRECTION OF THE ARM
# ABOVE. The runner now normalises `core/fixtures/<name>` to the bare name, and the one-line
# wrong way to write that is a `case core/fixtures/*)` glob taking the basename: `*` matches a
# space, so a fifteen-name joined list collapses to its LAST name and ONE fixture runs GREEN.
# That is not a weaker version of the refusal above — it is the refusal INVERTED, and the seed
# above cannot see it because a bare joined list matches no prefix and falls through untouched.
#
# THE ARGUMENT COUNT IS WHAT MAKES IT LEGIBLE: two names arrive in ONE argument, so an accepting
# run reports one fixture and calls the slice covered. The assertion is the refusal, keyed on
# the emitted row and on the ORIGINAL argument being its subject, for the reason Part 15b's
# header gives — the remedy paragraph names every cause unconditionally.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR15BP="$CONS2/err-part15b-path.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     "core/fixtures/touched-shippable core/fixtures/green-one" cwd-probe \
     >"$CONS2/out-part15b-path.txt" 2>"$ERR15BP"
rcbp=$?
L15BP="$(newest_log2)"
if [ "$rcbp" -eq 2 ] \
   && grep -qF '  core/fixtures/touched-shippable core/fixtures/green-one — not a fixture NAME' "$ERR15BP" \
   && grep -qF 'it carries whitespace' "$ERR15BP" \
   && [ -n "$L15BP" ] && ! grep -qF "===== FIXTURE " "$L15BP"; then
  ok "a SPACE-joined list written in the path form is still refused under the WHITESPACE reason, with the whole argument as the row's subject — a prefix match that took the basename would have collapsed it to one name and run a green suite over half the slice"
else
  bad "a path-form joined list was not refused under the whitespace reason (rc=$rcbp, log sections $(grep -cF '===== FIXTURE ' "${L15BP:-/dev/null}" 2>/dev/null)). The normalisation is matching with a glob rather than a fixture-name character class, so PC-S310's joined list is now ACQUITTED — one name of it runs, the run exits 0, and step 2 reads that as the whole slice covered"
fi

# --- Part 15c: the NEWLINE-joined shape, which is the one the filing actually describes -------
# THE ARM ABOVE SEEDS A SPACE-JOINED ARGUMENT AND THE FILED EPISODE IS NEWLINE-JOINED. Both
# arrive as one argument under zsh, so the seed above is a reachable shape — but a channel that
# sits only on it cannot say the mechanism the header, BL-226 and the CHANGELOG all name is
# covered. The first spelling of the predicate tested a literal space and PASSED Part 15b while
# a newline-joined and a tab-joined list were both still convicted as deleted drivers; an
# adversarial hand found that on the pushed tip. One seed per channel, never another arm on the
# same seed.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR15C="$CONS2/err-part15c.txt"
NL_ARG="touched-shippable
green-one"
TAB_ARG="$(printf 'touched-shippable\tgreen-one')"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     "$NL_ARG" cwd-probe >"$CONS2/out-part15c.txt" 2>"$ERR15C"
rc=$?
ERR15D="$CONS2/err-part15d.txt"
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     "$TAB_ARG" cwd-probe >/dev/null 2>"$ERR15D"
rcd=$?
if [ "$rc" -eq 2 ] && grep -qE ' — not a fixture NAME' "$ERR15C" \
   && ! grep -qE '^  [^ ].* — no run\.sh at' "$ERR15C" \
   && [ "$rcd" -eq 2 ] && grep -qE ' — not a fixture NAME' "$ERR15D" \
   && ! grep -qE '^  [^ ].* — no run\.sh at' "$ERR15D"; then
  ok "a NEWLINE-joined and a TAB-joined argument are both refused as unparsable NAMEs — the predicate covers the whitespace the filing describes, not only the literal space Part 15b seeds"
else
  bad "a newline-joined (rc=$rc) or tab-joined (rc=$rcd) argument was not refused under the name-shape reason. A predicate keyed on a literal space passes Part 15b and leaves the filed mechanism — and every tab-delimited caller — still convicted as a deleted driver"
fi

# THE NEWLINE-JOINED LIST IN THE PATH FORM, which is the shape the reference consumer would
# actually produce: step 2 derives its term as `core/fixtures/<dir>/` and zsh hands the whole
# unquoted list over as one argument. A `case core/fixtures/*)` glob matches a NEWLINE as
# happily as a space, so this seed and the space-joined one above are the same defect reached
# by the two spellings the filing and the step each describe — one seed per channel.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR15CP="$CONS2/err-part15c-path.txt"
NLP_ARG="core/fixtures/touched-shippable
core/fixtures/green-one"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     "$NLP_ARG" cwd-probe >"$CONS2/out-part15c-path.txt" 2>"$ERR15CP"
rccp=$?
L15CP="$(newest_log2)"
# THE WHOLE ROW, WITH ITS NEWLINE, MATCHED AS ONE STRING. A multi-line `grep -F` pattern is a
# list of ALTERNATIVES — it passes when EITHER line appears anywhere — so the obvious spelling
# here accepts a run whose row lost its subject entirely. Measured on mutant N2 in the battery
# below, which scored this shape correct while rewriting the argument out of the row. Both sides
# are folded onto one line before the comparison.
CP_FLAT="$(tr '\n' '\002' < "$ERR15CP")"
CP_WANT="$(printf '  %s — not a fixture NAME: it carries whitespace' "$NLP_ARG" | tr '\n' '\002')"
cp_row=0
case "$CP_FLAT" in *"$CP_WANT"*) cp_row=1 ;; esac
if [ "$rccp" -eq 2 ] && [ "$cp_row" -eq 1 ] \
   && [ -n "$L15CP" ] && ! grep -qF "===== FIXTURE " "$L15CP"; then
  ok "a NEWLINE-joined list in the path form is refused under the whitespace reason too, with BOTH its lines intact as the row's subject — the form step 2's own derivation produces cannot be collapsed to its last name by the prefix match"
else
  bad "a newline-joined path-form list was not refused under the whitespace reason with its whole argument as the row's subject (rc=$rccp, row matched=$cp_row, log sections $(grep -cF '===== FIXTURE ' "${L15CP:-/dev/null}" 2>/dev/null)). This is the exact shape step 2 hands an operator under zsh, so an accepting normalisation runs ONE fixture of the derived set and reports the cycle green"
fi

# --- Part 15c2: the PATH FORM IS ACCEPTED, and its run is the SAME RUN as the bare form -------
# The positive direction, and without it every arm around here passes for a runner that refuses
# the path form exactly as base did. Two runs of the same three-fixture set, one spelling per
# run, and the assertion is that the two logs' FIXTURE SECTION NAMES are identical — never the
# summary counts, which are equal for a run that normalised nothing and reported MISS on all
# three as surely as for one that ran them all.
#
# THE RANGE IS `base..theirs`, WHOSE DIFF TOUCHES A NAMED FIXTURE, and that is what makes the
# arm able to see a normalisation sited BELOW the coverage join. That join's membership test is
# `case " $* " in *" ${d} "*`, so a path-form set that is COMPLETE is convicted as incomplete by
# a mis-sited build and never reaches the loop at all. Over the quiet range the join has nothing
# to say and the two spellings agree for a reason that is not the subject. The three names are
# the whole diff-touched shippable set for this range — `touched-distonly` and `touched-deleted`
# are exempt — so the set is complete and a correct build exits 0.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE" theirs-tag "$CONS2" \
     core/fixtures/touched-shippable core/fixtures/touched-named core/fixtures/green-one \
     >"$CONS2/out-part15c2-path.txt" 2>"$CONS2/err-part15c2-path.txt"
rcp2=$?
LP2="$(newest_log2)"
SECP2="$(sec_set "$LP2")"
NORMP2="$(grep -cE '^NORMALISED: ' "${LP2:-/dev/null}" 2>/dev/null)" || NORMP2=0
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE" theirs-tag "$CONS2" \
     touched-shippable touched-named green-one \
     >"$CONS2/out-part15c2-bare.txt" 2>"$CONS2/err-part15c2-bare.txt"
rcb2=$?
LB2="$(newest_log2)"
SECB2="$(sec_set "$LB2")"
NORMB2="$(grep -cE '^NORMALISED: ' "${LB2:-/dev/null}" 2>/dev/null)" || NORMB2=0
if [ "$rcp2" -eq 0 ] && [ "$rcb2" -eq 0 ] && [ -n "$SECB2" ] && [ "$SECP2" = "$SECB2" ] \
   && [ "$NORMP2" -eq 3 ] && [ "$NORMB2" -eq 0 ]; then
  ok "a COMPLETE set spelled core/fixtures/<name>, on a range whose diff TOUCHES a named fixture, exits 0 and produces the IDENTICAL fixture-section list as the bare-name run of the same set — with one NORMALISED line per rewritten argument and none for the bare run"
else
  bad "the path-form run and the bare-name run did not agree (path rc=$rcp2 sections '${SECP2:-empty}' normalised=$NORMP2; bare rc=$rcb2 sections '${SECB2:-empty}' normalised=$NORMB2, expected 3 and 0). rc=2 on the path form with the bare form green is a normalisation sited BELOW the coverage join, which convicts a correct set as incomplete; equal rcs with different section lists is a rewrite the loop never saw; rc=1 is a normalisation sited before \$LOG exists and dying on an unbound variable"
fi

# --- Part 15c3: the TRAILING SLASH and the tests/ PREFIX, which are two separate strips --------
# Step 2 spells its term `core/fixtures/<dir>/` WITH the trailing slash, and the consumer half
# of the same path is `tests/fixtures/<name>` — `install.sh` splits what shares a parent here.
# A build that strips only `core/` leaves `fixtures/<name>`, one that strips only the
# `core/fixtures/` prefix leaves the whole `tests/` form untouched, and one that forgets the
# trailing slash leaves a name ending in `/`. All three still carry a slash, so all three are
# refused — an rc=2 here is the wrong fix, and rc=0 with the section present is the subject.
# Each shape runs alone so the three strips cannot cover for one another.
#
# EVERY OBSERVABLE IS CAPTURED AS A VALUE BEFORE THE NEXT RUN, and that is not tidiness. The
# log's name carries a SECOND-resolution timestamp, so two runs inside one wall-clock second
# resolve to the SAME path: holding the first run's path and grepping it after the second has
# written reads the SECOND run's bytes. Measured here — this arm failed on its first draft with
# both runs correct, because the trailing-slash log had already been overwritten by the tests/
# one. It is the same hazard `seed_record`'s suffix argument exists for, one file down.
p_normform() { # $1=argument $2=expected NORMALISED right-hand side -> "<rc> <sec> <norm>"
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" "$1" \
    >/dev/null 2>"$CONS2/err-normform.txt"
  local r=$? lg s=0 n=0
  lg="$(newest_log2)"
  { [ -n "$lg" ] && grep -qF "===== FIXTURE ${2} =====" "$lg"; } && s=1
  { [ -n "$lg" ] && grep -qF "NORMALISED: ${1} -> ${2}" "$lg"; } && n=1
  printf '%s %s %s' "$r" "$s" "$n"
}
T3="$(p_normform "core/fixtures/green-one/" green-one)"
S3="$(p_normform "tests/fixtures/green-one" green-one)"
if [ "$T3" = "0 1 1" ] && [ "$S3" = "0 1 1" ]; then
  ok "a TRAILING-SLASH argument and a tests/fixtures/<name> argument each run the named fixture and log their own rewrite — the trailing-slash strip and the second accepted prefix are separate properties and neither is covered by the other"
else
  bad "the trailing-slash form read '$T3' or the tests/fixtures form read '$S3', each expected '0 1 1' (rc, section present, rewrite logged). A strip keyed on 'core/' alone leaves 'fixtures/<name>', one keyed on 'core/fixtures/' alone leaves the whole consumer-layout spelling refused, and one that forgets the trailing slash leaves a name ending in '/': all three are a slash away from the name and all three refuse here, so an operator following step 2's own term is still wedged"
fi

# --- Part 15c4: the NORMALISED rows sit ABOVE any COVERAGE block ------------------------------
# Not cosmetic, and it is why the runner writes them where it does. Both readers of this log
# WINDOW from a `COVERAGE:` line to the next blank one — `cov_set` and `uns_set` at the head of
# this file are that grammar — so a `NORMALISED:` row landing inside the window is parsed as a
# refused directory and enters a set equality that has nothing to do with it. The run is driven
# with a path-form set that is INCOMPLETE, so both a rewrite and a COVERAGE block exist in the
# same log and their order can be read; a run with no refusal cannot express the ordering.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE" theirs-tag "$CONS2" \
     core/fixtures/touched-named core/fixtures/green-one \
     >/dev/null 2>"$CONS2/err-part15c4.txt"
rcn4=$?
LN4="$(newest_log2)"
n4_norm="$(grep -n '^NORMALISED: ' "${LN4:-/dev/null}" 2>/dev/null | tail -1 | cut -d: -f1)" || n4_norm=""
n4_cov="$(grep -n '^COVERAGE: ' "${LN4:-/dev/null}" 2>/dev/null | head -1 | cut -d: -f1)" || n4_cov=""
n4_count="$(grep -cE '^NORMALISED: ' "${LN4:-/dev/null}" 2>/dev/null)" || n4_count=0
n4_cov_read="$(cov_set "$LN4")"
if [ "$rcn4" -eq 2 ] && [ -n "$n4_norm" ] && [ -n "$n4_cov" ] && [ "$n4_norm" -lt "$n4_cov" ] \
   && [ "$n4_count" -eq 2 ] && [ "$n4_cov_read" = "touched-shippable," ]; then
  ok "every NORMALISED row is written ABOVE the COVERAGE block — two rewrites logged, the refusal list still reads EXACTLY the omitted fixture, and a row landing inside the block's window would have entered that set as a directory nobody named"
else
  bad "the NORMALISED rows are not above the COVERAGE block or are miscounted (rc=$rcn4, last NORMALISED line ${n4_norm:-none}, first COVERAGE line ${n4_cov:-none}, rewrites $n4_count expected 2, refusal list '${n4_cov_read:-empty}' expected 'touched-shippable,'). The readers of this log window from a COVERAGE line to the next blank one, so a rewrite row inside that window is read as a refused directory"
fi

# --- Part 15d: a SLASH-bearing argument, which no other arm observes -------------------------
# THE ONE-CHARACTER WRONG FIX IS DELETING THE `/` FROM THE PREDICATE'S CHARACTER CLASS, and
# before this arm existed the ONLY thing that went red was Mutant 13b's `FIXTURE ERROR: the
# name-shape probe anchor no longer occurs exactly once` — an anchor complaint, not a behaviour
# finding. An author who hits that message re-keys the anchor to their own spelling and the
# wrong fix then goes fully green. Predicted by an adversarial hand and CONFIRMED by building it:
# one FAIL, and it was the anchor row.
#
# A mutant cannot cover this: the mutation IS the wrong fix, so the thing that must fail is a
# behavioural arm reading the emitted row. `lib` is a real no-`run.sh` directory in this repo,
# so the slash case is not exotic — `lib/preamble.sh` is the shape a caller passing a path
# rather than a name actually produces.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR15E="$CONS2/err-part15e.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     "touched-shippable/run.sh" cwd-probe >/dev/null 2>"$ERR15E"
rce=$?
if [ "$rce" -eq 2 ] && grep -qE '^  touched-shippable/run\.sh — ' "$ERR15E" \
   && ! grep -qE '^  touched-shippable/run\.sh — no run\.sh at' "$ERR15E"; then
  ok "a SLASH-bearing argument is refused under the name-shape reason — deleting the slash from the predicate's class is a one-character wrong fix, and this is the only arm that sees it as behaviour rather than as a broken anchor"
else
  bad "a slash-bearing argument was not refused under the name-shape reason (rc=$rce). The predicate's slash half is untested by behaviour, and the only thing standing between that wrong fix and a green suite is a mutant anchor an author is invited to re-key"
fi

# --- Part 15d2: THE SLASH FORMS THAT ARE STILL REFUSED, EACH WITH THE SHAPE IT SAW ------------
# Accepting two prefixes is not accepting slashes, and the difference is one `case` arm wide.
# Three shapes, each in its own run: a path under no accepted prefix, an ABSOLUTE path, and a
# DEEPER path under an accepted one. A build that strips the basename off anything slash-bearing
# takes all three, and the two above become `bar` and `x` — names no fixture carries, so the run
# reports MISS and nothing says the argument was rewritten.
#
# THE ROW MUST NAME THE PATH SHAPE AND NOT THE WHITESPACE CAUSE. The remedy forks: a joined list
# is fixed by word-splitting the caller's variable, a path by passing the name, and the single
# sentence that used to serve both sent every path-form reader to a zsh remedy that changes
# nothing. So the refused-shape half is asserted as an ABSENCE of the whitespace wording on a
# row whose SUBJECT is the original argument — the presence conjunct beside it is what stops
# that absence passing against a run that said nothing at all.
p_pathshape() { # $1=argument $2=label
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" "$1" cwd-probe \
    >/dev/null 2>"$CONS2/err-pathshape.txt"
  local r=$? lg subj why
  lg="$(newest_log2)"
  subj=0; grep -qF "  ${1} — not a fixture NAME" "$CONS2/err-pathshape.txt" && subj=1
  why=0; grep -qF "  ${1} — not a fixture NAME: it carries whitespace" "$CONS2/err-pathshape.txt" && why=1
  if [ "$r" -eq 2 ] && [ "$subj" -eq 1 ] && [ "$why" -eq 0 ] \
     && [ -n "$lg" ] && ! grep -qF "===== FIXTURE " "$lg"; then
    ok "$2 is refused with the ORIGINAL argument as the row's subject and a reason naming the path shape, not the zsh joined-list cause"
  else
    bad "$2 was not refused under a path-shape reason (rc=$r, row present=$subj, whitespace wording=$why). rc=0 is a normalisation that strips the basename off any slash-bearing argument — '${1}' then becomes a name no fixture carries and the run reports MISS; the whitespace wording is the pre-fix single sentence, which sends a path-form reader to a remedy about word-splitting that changes nothing about their argument"
  fi
}
p_pathshape "foo/bar"             "a path under NO accepted prefix"
p_pathshape "/abs/x"              "an ABSOLUTE path"
p_pathshape "core/fixtures/deep/er" "a DEEPER path under an accepted prefix"

# --- Part 15e: the EMPTY NAME keeps the ORIGINAL argument as its row's subject -----------------
# `core/fixtures/` carries the accepted prefix and NO name. Stripping it yields the empty string,
# and a refusal row whose subject were that remainder opens with a SPACE — the row loses its
# subject entirely, every reader of this log keys on a row's first token, and `uns_set` scores
# the refusal ABSENT. A run that refused correctly and a run that refused nothing then read the
# same, which is the acquitting direction.
#
# READ WITH `uns_subj`, NOT `uns_set`: the latter's capture is a `[^[:space:]/]` class and
# cannot spell a subject carrying slashes, so it returns empty on a perfectly good row. The
# CONTROL for that is the same reader over Part 14's run, which must still show the bare name —
# a reader that returned everything, or nothing, would pass this arm either way.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR15F="$CONS2/err-part15f.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     "core/fixtures/" cwd-probe >/dev/null 2>"$ERR15F"
rcf=$?
L15F="$(newest_log2)"
SUBJF="$(uns_subj "$L15F")"
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     named-distonly green-one >/dev/null 2>/dev/null
SUBJCTL="$(uns_subj "$(newest_log2)")"
if [ "$rcf" -eq 2 ] && [ "$SUBJF" = "core/fixtures/," ] && [ "$SUBJCTL" = "named-distonly," ] \
   && grep -qF '  core/fixtures/ — not a fixture NAME' "$ERR15F"; then
  ok "an argument that is the bare prefix with NO name is refused with the literal 'core/fixtures/' as its row's subject, and the log's own refusal reader sees it (control: the same reader over a bare-name refusal reads 'named-distonly')"
else
  bad "the empty-name argument did not keep its subject (rc=$rcf, logged subject '${SUBJF:-empty}' expected 'core/fixtures/,'; control over a bare-name refusal read '${SUBJCTL:-empty}' expected 'named-distonly,'). A row whose subject is the STRIPPED remainder opens with a space and is invisible to every reader of this log — the refusal is emitted and scores as an absence, which is the acquitting direction"
fi

# --- Part 16: a wholly legitimate set does NOT trip the arm ----------------------------------
# The negative direction, and it is keyed on the arm's OWN MESSAGE rather than on the exit code:
# exit 2 has six producers in this runner and a control reading only the code cannot tell them
# apart. The positive conjunct is a fixture section — an arm asserting only that nothing was said
# passes against a subject replaced by `exit 0`.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
ERR16="$CONS2/err-part16.txt"
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     green-one cwd-probe touched-named touched-shippable \
     >"$CONS2/out-part16.txt" 2>"$ERR16"
rc=$?
L16="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$L16" ] && grep -qF "===== FIXTURE touched-named =====" "$L16" \
   && ! grep -qF "COVERAGE: the named set contains" "$L16" \
   && ! grep -qF "no consumer can run" "$ERR16"; then
  ok "a set of four directories a consumer CAN run reaches the loop and exits 0 — the arm stays silent on correct input"
else
  bad "a wholly shippable named set was refused, or never reached the loop (rc=$rc). An over-completeness arm that fires on a correct slice wedges every self-update, which is worse than the orphan it prevents"
fi

# --- Part 17: THE READ IS AT THEIRS, not off the distribution checkout -----------------------
# Four directories whose disk state and theirs state DISAGREE, in one run, two convicted and two
# acquitted. An implementation probing `$DIST/core/fixtures/<d>/...` on the filesystem returns the
# exact inverse of this set, and would pass a seed where the two agreed. The distribution checkout
# is not the tree being delivered: `$DIST` is a working copy at whatever revision the caller left
# it, and the slice is computed from `theirs`.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
     theirs-only-distonly theirs-only-nodriver disk-only-distonly disk-missing-driver green-one \
     >"$CONS2/out-part17.txt" 2>"$CONS2/err-part17.txt"
rc=$?
UNS17="$(uns_set "$(newest_log2)")"
if [ "$rc" -eq 2 ] && [ "$UNS17" = "theirs-only-distonly,theirs-only-nodriver," ]; then
  ok "the exclusions are read AT THEIRS: the two directories unshippable at theirs are refused though the checkout says otherwise, and the two the checkout condemns are acquitted"
else
  bad "the refusal is '${UNS17:-empty}', not 'theirs-only-distonly,theirs-only-nodriver,' (rc=$rc). 'disk-only-distonly,disk-missing-driver,' is the answer a probe reading \$DIST off the filesystem gives, and it is wrong in both directions at once: it acquits an orphan bound for the consumer and convicts two fixtures the pull delivers"
fi

# --- Part 18: the arm is SITED AFTER the ref resolution --------------------------------------
# Both of its probes are `cat-file -e` at theirs. Against an unresolvable THEIRS every one of them
# fails, so an arm placed above the resolution loop convicts the ENTIRE named set — a check whose
# failure mode is to indict correct input, pointing the operator at a slice that is fine. Both
# names here are directories the distribution genuinely ships, so the only thing the misplaced
# copy can produce is a false conviction. The assertion is on the two MESSAGES, not on the exit
# code, which is 2 either way.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_THEIRS" no-such-theirs-ref "$CONS2" green-one touched-shippable \
  >"$CONS2/out-part18.txt" 2>"$CONS2/err-part18.txt"
rc=$?
L18="$(newest_log2)"
if [ "$rc" -eq 2 ] && [ -n "$L18" ] \
   && grep -qF "COVERAGE: UNRESOLVABLE — 'no-such-theirs-ref' does not name a commit" "$L18" \
   && ! grep -qF "COVERAGE: the named set contains" "$L18"; then
  ok "an unresolvable THEIRS exits on the RESOLUTION arm — the over-completeness arm cannot speak before its own probes can resolve"
else
  bad "an unresolvable THEIRS did not exit on the resolution arm (rc=$rc). With the over-completeness arm above it, every \`cat-file -e\` fails and both of these perfectly shippable directories are convicted for a reason that has nothing to do with the slice"
fi

# --- Part 19: the arm is SITED AFTER the WRONG-REPO guard ------------------------------------
# The input the arm above cannot see: both refs resolve here, so Part 18 is satisfied by a copy
# sited between the resolution loop and this guard. What that copy gets wrong is a checkout with
# no `core/fixtures` tree at theirs — every probe fails again, and both named directories are
# condemned instead of the repo.
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one touched-shippable \
  >"$CONS2/out-part19.txt" 2>"$CONS2/err-part19.txt"
rc=$?
L19="$(newest_log2)"
if [ "$rc" -eq 2 ] && [ -n "$L19" ] && grep -qF "COVERAGE: WRONG-REPO" "$L19" \
   && ! grep -qF "COVERAGE: the named set contains" "$L19"; then
  ok "a \$DIST with no core/fixtures at theirs exits on the WRONG-REPO guard — the over-completeness arm is sited below it and convicts nothing"
else
  bad "a checkout with no core/fixtures at theirs was reported as an over-complete named set (rc=$rc), not as the wrong repo. Both refs resolve here, so the resolution loop lets this through and only the wrong-repo guard's position keeps the arm from indicting two directories the distribution genuinely ships"
fi

# --- Parts G1 to G5: the RECORDED GATE VERDICT is what authorises the cycle ------------------
# Step 2 cuts a branch, writes the machinery slice, pushes and auto-merges with NO operator
# gate, and until this arm existed the only record of the decision that permitted the write was
# the operating agent's narration in a PR body. `self-update-gate.sh` prints TSV and the runner
# ran whatever it was handed, so a cycle that never invoked the gate at all was
# indistinguishable from one the gate cleared.
#
# THE PARTS ARE SPLIT BY WHAT EACH ONE CAN SEE, and no two share an input:
#   G1  no record at all                     the state every cycle starts in
#   G2  a record whose verdict is DEFER      a gate that RAN and said no
#   G3  an OK record for a DIFFERENT range   the input a presence-only check accepts
#   G4  the SHIPPING gate's own record       the only part that proves the two grammars agree
#   G5  a DEFER record NEWER than an OK      the input a first-match-wins reader accepts
#
# EVERY ONE OF THESE USES ITS OWN CONSUMER TREE. `$CONS`/`$CONS2` already carry the seeded OK
# records for every range the parts above drive, and an arm asserting a REFUSAL cannot be run in
# a directory where an acquitting record exists — the refusal would be the seed's absence rather
# than the arm's subject, and seeding is not something a part should have to undo.

# --- Part G1: NO record for this range is a refusal, not a green run --------------------------
# Keyed on the `GATE-RECORD:` line in the runner's OWN LOG as well as the exit code, because
# exit 2 has seven producers in this runner and a part reading only the code cannot say which
# one answered. The named set is wholly legitimate for this range — the only thing wrong here is
# that nothing authorised the cycle.
#
# A RECORD FOR AN UNRELATED RANGE IS SEEDED FIRST, AND IT IS WHAT MAKES THIS PART ITS OWN. An
# EMPTY record directory is the delivery-pull state Part G12 owns, where proceeding is correct;
# with one record present this consumer has demonstrably recorded a verdict before, so the
# requirement binds. The two parts are one property apart and the seed is the property.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 190 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G1's unrelated-range record"
ERRG1="$GCONS/err-g1.txt"; OUTG1="$GCONS/out-g1.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >"$OUTG1" 2>"$ERRG1"
rc=$?
LG1="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG1" ] && grep -qF "GATE-RECORD:" "$LG1"; then
  ok "with NO gate record the runner refuses with exit 2 and a GATE-RECORD line in its own log"
else
  bad "the runner ran the fixtures with no recorded gate verdict at all (rc=$rc, log '${LG1:-none}'). Step 2 pushes and auto-merges autonomously, so the gate's recorded OK is the only artifact of the decision that permitted the write — without this the suite reports green for a cycle nothing authorised"
fi
if grep -qF "self-update-gate.sh" "$ERRG1"; then
  ok "the stderr remedy names the exact gate command, so the operator is not left to derive it"
else
  bad "the refusal did not name the gate command on stderr. A refusal whose remedy the reader has to reconstruct is where a cycle gets rerun with the check switched off"
fi
# ORDERING, both channels in one arm — the refusal must precede the loop, or a green verdict is
# printed above the finding that condemns it.
if [ -n "$LG1" ] && ! grep -qF "===== FIXTURE " "$LG1" && ! grep -qE '^ +(ok|FAIL|MISS) +' "$OUTG1"; then
  ok "the gate-record refusal is ORDERED BEFORE the fixture loop — no per-fixture section and no per-fixture verdict"
else
  bad "the runner reported fixture verdicts before refusing for a missing gate record: sections $(grep -cF '===== FIXTURE ' "$LG1" 2>/dev/null), stdout verdicts $(grep -cE '^ +(ok|FAIL|MISS) +' "$OUTG1" 2>/dev/null)"
fi

# --- Part G2: a DEFER record is a refusal ----------------------------------------------------
# The input a PRESENCE check cannot see. A record exists, its shas match this exact range, and
# the gate said do not proceed — so a reader that only asks whether a record is there acquits
# the one case the gate explicitly refused.
gin_restore
gin_seed_defer 195
ERRG2="$GCONS/err-g2.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>"$ERRG2"
rc=$?
LG2="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG2" ] && grep -qF "GATE-RECORD:" "$LG2" && grep -qF "DEFER" "$LG2"; then
  ok "a gate record for this range whose verdict is DEFER is refused, and the log says which verdict it read"
else
  bad "a DEFER verdict for this exact range did not stop the run (rc=$rc). A reader asking only whether a record EXISTS acquits the one case the gate explicitly refused, which is worse than no check at all"
fi

# --- Part G3: an OK record for a DIFFERENT range is a refusal --------------------------------
# The input only a sha-matching reader can see. The record is real, its verdict is OK, and it
# classified a different pull entirely — a stale artifact from the previous self-update, which is
# the state a consumer's `_bmad-output/` is in on every cycle after the first.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 196 >/dev/null \
  || bad "FIXTURE ERROR: could not seed the wrong-range record for Part G3"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
rc=$?
LG3="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG3" ] && grep -qF "GATE-RECORD:" "$LG3"; then
  ok "an OK record classifying a DIFFERENT range does not authorise this one — the stale artifact of the previous cycle is refused"
else
  bad "an OK record for another range authorised this cycle (rc=$rc). After the first self-update a consumer's _bmad-output/ always holds one, so a reader that does not compare shas is permanently satisfied by an artifact that classified a different pull"
fi

# --- Part G4: THE SHIPPING GATE'S OWN RECORD, not a forged one -------------------------------
# The only part here that establishes the two halves agree. Every other part seeds a record this
# fixture's own author wrote, so they all prove the reader accepts its author's grammar — which
# stays true through a change to BOTH sides. This one runs `self-update-gate.sh` against the
# throwaway distribution and the seeded consumer, then hands the runner whatever it wrote.
#
# THE THROWAWAY DIST CARRIES A `core/git-hooks/pre-push`, and that is required rather than
# decorative: with no hook at the consumer and none in the distribution the gate emits
# SELF-UPDATE-UNDECIDED ("no pre-push hook found") and records a verdict this runner correctly
# refuses — the part would then fail for a reason that has nothing to do with the join.
GATE_SH="$RECONCILE/self-update-gate.sh"
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
if [ ! -f "$GATE_SH" ]; then
  bad "FIXTURE ERROR: self-update-gate.sh is not beside the runner at $RECONCILE, so the record's WRITER cannot be driven and nothing here establishes that the two grammars agree"
else
  G_OUT="$GCONS/out-g4-gate.txt"; G_ERR="$GCONS/err-g4-gate.txt"
  gin_restore
  bash "$GATE_SH" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" >"$G_OUT" 2>"$G_ERR"
  g_rc=$?
  G_REC="$(ls -t "$GLOG"/self-update-gate-*.md 2>/dev/null | head -1)"
  if [ "$g_rc" -eq 0 ] && [ -n "$G_REC" ] && [ -s "$G_REC" ]; then
    ok "the SHIPPING gate writes a record of its own under _bmad-output/ai-dlc-update/"
    # The record has to say OK for the join to be observable at all; if the gate defers on this
    # seed the arm below cannot distinguish a reader defect from a correct refusal, so the
    # verdict is read and reported rather than assumed.
    g_verdict="$(awk 'index($0, "# verdict:") == 1 { s = substr($0, 11); gsub(/[[:space:]]/, "", s); print s; exit }' "$G_REC")"
    if [ "$g_verdict" = "OK" ]; then
      # IN STEP 2'S ORDER: the slice is written between the gate and the runner, so this arm
      # exercises the join on the state a real cycle presents rather than on a tree nothing
      # touched. Driving the two back to back is what let the shipped runner refuse every
      # legitimate self-update while this part stayed green.
      gin_write_slice
      bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
      rc=$?
      LG4="$(newest_glog)"
      # THE COLUMN COUNT IS READ BEFORE THE VERDICT IS SCORED, so "the writer has not landed
      # yet" and "the join is broken" are two different rows rather than one. A record whose
      # input lines carry two fields is the PRE-correction gate: the reader needs the core path
      # to accept a file the slice moved to `theirs`, and without it every line is unevaluable.
      g4_cols="$(awk -F'\t' 'index($0, "# input: ") == 1 { print NF; exit }' "$G_REC" 2>/dev/null)"
      if [ "$rc" -eq 0 ] && [ -n "$LG4" ] && grep -qF "===== FIXTURE green-one =====" "$LG4" \
         && ! grep -qF "GATE-RECORD:" "$LG4"; then
        ok "the runner ACCEPTS the record the shipping gate wrote, in step 2's real order, and reaches the loop — the writer's grammar and the reader's agree, established by running both and not by one author writing both"
      elif [ "${g4_cols:-0}" -lt 3 ]; then
        bad "PENDING the three-column writer: the shipping gate wrote ${g4_cols:-0}-field input lines and this reader requires three (path, digest, CORE PATH). The core path is what lets an input the slice moved to \`theirs\` be accepted, so a two-column record cannot express the legitimate post-write state at all. This is the only arm here that reads the real writer, and it stays red until that half lands"
      else
        bad "the runner refused the record the SHIPPING gate wrote for this exact range (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG4" 2>/dev/null | cut -c1-160). Every other part here seeds a record this fixture authored, so they would all stay green through a change that broke the join; this is the only arm that can see it"
      fi
      if [ -n "$LG4" ] && grep -qF "$(basename "$G_REC")" "$LG4"; then
        ok "the runner's log header CITES the gate record it accepted, so the two artifacts of one cycle name each other"
      else
        bad "the runner ran on a gate record and did not name it in its log. The pair of records is the approval artifact for an autonomous write, and a log that does not say which record authorised it leaves the reader to guess"
      fi
    else
      bad "FIXTURE ERROR: the shipping gate recorded verdict '${g_verdict:-<absent>}' on this seed, not OK, so the acceptance join below could not be scored. Gate stdout: $(head -1 "$G_OUT" 2>/dev/null | cut -c1-160)"
    fi
  else
    bad "PENDING hand-gate: the shipping self-update-gate.sh wrote no record under $GLOG (rc=$g_rc). The record's WRITER is the other half of batch 78 and lands in a separate commit; until it does, this part is the only failing one here and its failure is that absence, not a defect in the reader"
  fi
fi

# --- Part G5: the NEWEST matching record decides, and it is picked by NAME --------------------
# The input a first-match-wins reader accepts. An OK is written, the operator changes something,
# the gate runs again and DEFERS — and a reader that stops at the first matching record it finds
# revives the superseded OK. Both records match this range exactly, so nothing but the ordering
# separates them.
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
gin_restore
G5_OK="$(SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 100)" \
  || bad "FIXTURE ERROR: could not seed Part G5's OK record"
G5_DEFER="$(SR_INPUTS="$(sr_required_inputs "$GCONS")" seed_record "$GLOG" "$DIST" "$D_BASE" "$D_THEIRS" DEFER 900)" \
  || bad "FIXTURE ERROR: could not seed Part G5's DEFER record"
# THE SEED IS ASSERTED TO DISCRIMINATE BEFORE IT IS SCORED. Two records written inside the same
# wall-clock second sort identically, and the arm would then pass for either implementation.
if [ -n "${G5_OK:-}" ] && [ -n "${G5_DEFER:-}" ] \
   && [ "$(basename "$G5_DEFER")" \> "$(basename "$G5_OK")" ]; then
  ok "SEED: Part G5's DEFER record sorts strictly AFTER its OK record by name, so the two orderings give different answers"
else
  bad "FIXTURE ERROR: Part G5's two records do not order ('${G5_OK:-none}' then '${G5_DEFER:-none}'). Where the newest and the oldest are the same file, an implementation picking either passes, and the arm below asserts nothing"
fi
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one >/dev/null 2>&1
rc=$?
LG5="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG5" ] && grep -qF "GATE-RECORD:" "$LG5"; then
  ok "with a DEFER record NEWER than an OK for the same range the runner reads the newest and refuses — a superseded OK cannot be revived by reaching further back"
else
  bad "a superseded OK record authorised the cycle (rc=$rc). The gate ran twice and its LAST answer was DEFER; a reader taking the oldest, or the first it happens to encounter, acts on a verdict the gate has already withdrawn"
fi

# --- Parts G6 to G11: the record binds the CONSUMER TREE, and WHICH WAY an input moved --------
# The gate's verdict is a DIFFERENTIAL — it runs the consumer's CURRENT copy of each gating
# script against the incoming one — so the same command over one range answers differently as
# the tree moves. But "nothing moved" is the WRONG rule and it refused every legitimate
# self-update: step 2's order is gate, WRITE THE SLICE, runner, so the files the slice replaced
# are exactly the ones that differ. Measured on the gate's own seed driving both shipping
# programs in that order: 4 of 9 recorded inputs moved, every one to precisely the `theirs` blob
# of its core path.
#
# SO THE DISCRIMINATOR IS WHICH INPUT MOVED AND TOWARD WHAT. `now` equal to the recorded digest
# is untouched; equal to `theirs:<core path>` is the written slice; equal to neither is a third
# hand. And a digest RECORDED as the `theirs` blob, on a path the range changes, is a gate that
# compared the incoming file with itself — the one case where record and tree agree perfectly and
# the verdict is still worthless.
#
# Each part below is the ONE input that separates a reader from a weaker one:
#   G6   a gating script the SLICE wrote           the NORMAL order — a "nothing moved" reader refuses
#   G7   a record naming NO inputs                 a reader looping over zero lines accepts
#   G8   a third-hand edit                         a reader accepting any change accepts
#   G9   a recorded ABSENT that is now PRESENT     a reader skipping ABSENT accepts
#   G10  a recorded digest whose file is now ABSENT  a reader testing only "differs" accepts
#   G11  an input value that is neither hex nor ABSENT  a reader `continue`-ing on the unknown
#   G14  a LATE GATE                               a digest reader cannot see it — the digests agree
#   G15  a forged single-line record               a reader trusting the record's own input list
#   G16  a `-` row naming a non-hook core path     a reader resolving `-` against anything
#
# THE TWO GATING SCRIPTS `seed.sh` WRITES ARE THE SUBJECTS. `gate-changed.sh` moves across
# base..theirs, so it is the one the slice rewrites; `gate-steady.sh` does not, so it must hold
# its recorded digest through every legitimate flow. Both are named by the consumer's own hook,
# which is what the runner derives its required set from.

# --- SEED CONTROL: the two gating scripts must DIFFER across the range in one direction only ---
# `gate-changed.sh` moving and `gate-steady.sh` not moving is the property every part below
# turns on, and where both moved (or neither did) a reader accepting anything and a reader
# accepting only `theirs` would give the same answer on every input here.
gin_cb="$(git -C "$DIST" rev-parse -q --verify "${D_BASE}:core/scripts/gate-changed.sh" 2>/dev/null)"
gin_ct="$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/gate-changed.sh" 2>/dev/null)"
gin_sb="$(git -C "$DIST" rev-parse -q --verify "${D_BASE}:core/scripts/gate-steady.sh" 2>/dev/null)"
gin_st="$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/gate-steady.sh" 2>/dev/null)"
if [ -n "$gin_cb" ] && [ -n "$gin_ct" ] && [ "$gin_cb" != "$gin_ct" ] \
   && [ -n "$gin_sb" ] && [ "$gin_sb" = "$gin_st" ] \
   && [ -f "$GCONS/.githooks/pre-push" ]; then
  ok "SEED: the consumer has its own pre-push hook, and of the two scripts it names exactly ONE changes across base..theirs — so a reader accepting any change and one accepting only \`theirs\` give different answers"
else
  bad "FIXTURE ERROR: the gating-script seed does not discriminate (changed ${gin_cb:-none}->${gin_ct:-none}, steady ${gin_sb:-none}->${gin_st:-none}, hook $([ -f "$GCONS/.githooks/pre-push" ] && echo present || echo ABSENT)). Where both scripts move, or neither does, every arm below passes for a reader that accepts any post-record content"
fi

# --- Part G6: THE NORMAL ORDER — gate, write the slice, runner ACCEPTS ------------------------
# THE LOAD-BEARING ARM, and the one whose absence let the shipped runner refuse every legitimate
# self-update. Step 2 runs the gate on the pre-write tree, writes the slice, then runs this
# runner; the recorded digest of every script the slice replaced is therefore STALE BY DESIGN.
# Measured on the gate's own seed with both shipping programs driven in that order: 4 of 9
# recorded inputs moved, all four to exactly the `theirs` blob. An arm that only ever ran the
# gate and the runner back to back — with nothing written between — could not see it.
gin_restore
gin_seed_clean 200
gin_write_slice
ERRG6="$GCONS/err-g6.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG6"
rc=$?
LG6="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG6" ] && grep -qF "===== FIXTURE green-one =====" "$LG6" \
   && ! grep -qF "GATE-RECORD:" "$LG6"; then
  ok "THE NORMAL ORDER: gate, write the slice, runner — a gating script now holding what this pull SHIPS is the slice the cycle just wrote, and the run reaches the loop"
else
  bad "the legitimate flow was REFUSED (rc=$rc): $(grep -m2 '^GATE-RECORD:' "$LG6" 2>/dev/null | tr '\n' ' ' | cut -c1-200). Step 2 writes the slice BETWEEN the gate and this runner, so the recorded digests of the replaced scripts are stale by design; a rule spelled 'nothing moved' fails closed on every self-update whose range changes a gating script"
fi
# The UNTOUCHED script must still be compared, or the arm above passes for a reader that accepts
# any post-record content whatsoever.
if [ "$(gin_hash "$GIN_STEADY")" = "$gin_sb" ]; then
  ok "...and the script the range does NOT change still holds its recorded content, so the acceptance above is about the slice and not about the check having stopped looking"
else
  bad "gate-steady.sh moved during Part G6, so the acceptance cannot be attributed to the theirs-blob rule. Every arm here would pass for a reader comparing nothing"
fi

# --- Part G7: a record naming NO inputs is malformed ------------------------------------------
# Zero lines to compare is a comparison that cannot fail, and its silence is byte-identical to a
# comparison that passed.
gin_restore
gin_seed "$SR_NO_INPUTS" 210
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG7="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG7" ] && grep -qF "GATE-RECORD:" "$LG7"; then
  ok "a record for this range, verdict OK, naming NO input files is refused — nothing to compare is not the same as nothing changed"
else
  bad "a record naming no inputs authorised the cycle (rc=$rc). A loop over zero input lines reports agreement having compared nothing, which is the silent pass the input binding exists to remove"
fi

# --- Part G8: a THIRD HAND is refused ---------------------------------------------------------
# One property from Part G6: the same script, changed after the record, but to content that is
# neither what was recorded nor what this pull ships. A reader that accepted G6 by dropping the
# comparison altogether accepts this too, and only the pair can tell the two readers apart.
gin_restore
gin_seed_clean 220
printf '%s\n' 'neither the recorded content nor what the pull ships' > "$GCONS/$GIN_CHANGED"
ERRG8="$GCONS/err-g8.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG8"
rc=$?
LG8="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG8" ] && grep -qF "GATE-RECORD: INPUT-MOVED $GIN_CHANGED" "$LG8"; then
  ok "a gating script holding content that is NEITHER the recorded digest NOR what the pull ships is refused as INPUT-MOVED — the acceptance in Part G6 is keyed on the theirs blob, not on 'something changed'"
else
  bad "a third hand edited a file the verdict READ, to content this pull does not ship, and the runner accepted the record (rc=$rc). Then Part G6 passes for a reader that stopped comparing, and the tree binding is gone"
fi
if grep -qF "AS IT NOW STANDS" "$ERRG8"; then
  ok "the remedy tells the operator to re-run the gate against the tree as it now stands, not merely that something is wrong"
else
  bad "the INPUT-MOVED refusal gave the generic missing-record remedy. The operator has a record and will read 'run the gate' as already done"
fi
gin_restore

# --- Part G9: a recorded ABSENT that is now PRESENT, with content the pull does NOT ship -------
# Absence is a recorded VALUE. The gate reads inputs that are not there — a script the hook names
# and the consumer lacks — and its verdict rests on that absence, so a file ARRIVING moves the
# verdict exactly as an edit does. The exception the slice earns is asserted in Part G17.
gin_restore
gin_seed "$(printf '# input: %s\tABSENT\tcore/scripts/gate-steady.sh\n%s' \
  "scripts/ai-dlc/appeared-since.sh" "$(sr_required_inputs "$GCONS")")" 230
mkdir -p "$GCONS/scripts/ai-dlc"
printf '%s\n' 'written after the gate ran, and not what the pull ships' \
  > "$GCONS/scripts/ai-dlc/appeared-since.sh"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG9="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG9" ] && grep -qF "INPUT-MOVED" "$LG9" && grep -qF "appeared-since" "$LG9"; then
  ok "a path the record read as ABSENT and the consumer now holds, with content the pull does not ship, is refused — absence is a value, compared in both directions"
else
  bad "a file that appeared after the gate ran did not move the verdict (rc=$rc). A reader treating ABSENT as 'nothing to check' acquits exactly the direction where a new file arrives between the gate and the run"
fi
rm -f "$GCONS/scripts/ai-dlc/appeared-since.sh"

# --- Part G10: a recorded DIGEST whose file is now ABSENT -------------------------------------
# The mirror of G9, and the input a reader testing only "the hashes differ" cannot see: there is
# no hash to differ from once the file is gone.
gin_restore
gin_seed_clean 240
GIN_SAVED="$(cat "$GCONS/$GIN_STEADY")"
rm -f "$GCONS/$GIN_STEADY"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG10="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG10" ] && grep -qF "INPUT-MOVED $GIN_STEADY" "$LG10"; then
  ok "a path recorded with a digest and now ABSENT from the consumer is refused — a reader comparing only two hashes has none to compare here"
else
  bad "a recorded input file was DELETED after the gate ran and the record was still accepted (rc=$rc). An absent file produces no hash, so a check spelled as 'the hashes differ' passes over it silently"
fi
printf '%s\n' "$GIN_SAVED" > "$GCONS/$GIN_STEADY"; chmod +x "$GCONS/$GIN_STEADY"

# --- Part G11: an input VALUE that is neither a digest nor ABSENT -----------------------------
# A line this reader cannot evaluate. Skipping it is a record silently authorising whatever it
# could not spell, and the skip is invisible — the run goes green with one fewer comparison.
gin_restore
gin_seed "$(printf '# input: %s\tmaybe-changed\tcore/scripts/gate-steady.sh' "$GIN_STEADY")" 250
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG11="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG11" ] && grep -qF "GATE-RECORD:" "$LG11"; then
  ok "an input value that is neither a 40-hex digest nor ABSENT is refused rather than skipped"
else
  bad "an uninterpretable input value was skipped and the record accepted (rc=$rc). A reader that continues past what it cannot spell reports agreement over a line it never evaluated, and nothing announces the missing comparison"
fi

# --- Part G14: A LATE GATE is refused, and NO DIGEST COMPARISON CAN SEE IT --------------------
# The mirror of G6 and the case that makes the whole design necessary. Run the gate AFTER the
# write and every gating script's current copy IS the incoming version, so `cur` and `new` are
# the same bytes, the differential reads OK for the one reason that means nothing, and the record
# it writes carries post-write digests that the runner then re-reads and finds in perfect
# agreement. Record and tree match exactly; the verdict is worthless.
#
# It is keyed on the RANGE instead: a digest recorded as the `theirs` blob, for a path the range
# CHANGES, says the consumer already held the incoming version when the gate ran.
gin_restore
gin_write_slice                      # the slice, written FIRST
gin_seed_clean 270                   # ...and the gate run after it, recording post-write digests
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG14" ] && grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14"; then
  ok "a verdict taken AFTER the slice was written is refused as PRE-WRITTEN — the gate compared the incoming script with a copy of itself, and every digest in that record agrees with the tree"
else
  bad "a gate run on the already-written tree authorised the cycle (rc=$rc). Its OK says only that the file equals itself, and no digest comparison can catch it: the record and the tree agree perfectly. The range is what separates them — recorded == theirs, on a path base..theirs changes"
fi
gin_restore

# --- Part G14b: A SPLIT STAMP IS NOT A SELF-COMPARISON, AND G14's KEY CANNOT TELL THEM APART --
# The false positive in G14's own predicate, and the reason the arm above is not the whole rule.
# A consumer whose `skill_commit` runs ahead of `commit` already holds a PRIOR self-update's
# delivery for some machinery paths. For those, a gate run on its tree records the `theirs` blob
# for a path the range changes — G14's three conjuncts, satisfied honestly — and the cycle is
# refused forever: `commit` advances only under a gated apply, so nothing clears it.
#
# Measured on the reference consumer at 0.542.0 -> 0.547.0 before this arm existed: two machinery
# paths refused, the runner exited 2, and step 2 could not run its fixtures at all.
#
# THE WORLD IS THE SAME AS G14's IN EVERY RESPECT BUT ONE. The slice is written and the record
# carries post-write digests, exactly as above; what differs is a `# skill-commit:` header naming
# an intermediate that already carried that blob. One property apart, in the same run, so the arm
# discriminates between the two cases rather than merely firing on one of them.
gin_write_slice
SR_SKILL_COMMIT="$(git -C "$DIST" rev-parse "${D_SPLIT}^{commit}" 2>/dev/null)" \
  gin_seed_clean 271
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14B="$(newest_glog)"
if [ "$rc" -ne 2 ] || { [ -n "$LG14B" ] && ! grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14B"; }; then
  ok "a split stamp is NOT refused as PRE-WRITTEN — the recorded skill_commit already carried that blob, so the gate read a prior self-update's delivery rather than comparing this pull's file with itself"
else
  bad "a legitimate split-stamp consumer was refused as PRE-WRITTEN (rc=$rc). Its skill_commit already held that blob, so no self-comparison occurred; refusing it wedges every self-update on that consumer permanently, because commit advances only under a gated apply"
fi
gin_restore

# --- Part G14c: THE ACQUITTAL MUST NOT COVER G14's OWN SUBJECT -------------------------------
# The exemption's probe, and the arm that stops G14b from being a hole. Step 2 advances the stamp
# to `theirs` as part of writing the slice, so a gate RE-RUN after the write records
# `skill_commit == theirs` — and a fix keyed on the blob alone then acquits exactly the case G14
# exists to catch, because `theirs:P` trivially equals itself. Driven while building this fix:
# without the equality guard the seeded self-comparison went from REFUSED to ACQUITTED while G14b
# behaved identically, so the blob test could not separate them.
#
# A legitimate split stamp sits at a STRICTLY EARLIER release — `skill_commit` runs ahead of
# `commit`, never ahead of the target — which is what makes excluding equality the right key.
gin_write_slice
SR_SKILL_COMMIT="$(git -C "$DIST" rev-parse "${D_THEIRS}^{commit}" 2>/dev/null)" \
  gin_seed_clean 272
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14C="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG14C" ] && grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14C"; then
  ok "a record whose skill_commit IS theirs is still refused — that is the post-write re-run, not a split stamp, and the blob test alone cannot tell it from one"
else
  bad "a gate re-run after the write was ACQUITTED by the split-stamp exemption (rc=$rc). skill_commit == theirs is what step 2 itself writes, so an exemption that accepts it covers the very case the PRE-WRITTEN arm exists to catch"
fi
gin_restore

# --- Part G14d: AN ABBREVIATED RECORDED SHA IS THE SAME COMMIT -------------------------------
# The comparison is on RESOLVED shas, never on the header string — the rule this file states for
# `base`/`theirs` and which the first cut of the split-stamp field broke. A record carrying an
# abbreviated `skill-commit` names one commit; compared as text against a full sha it differs,
# the equality guard above silently never fires, and G14c's refusal is defeated by a spelling.
gin_write_slice
SR_SKILL_COMMIT="$(git -C "$DIST" rev-parse --short=8 "${D_THEIRS}^{commit}" 2>/dev/null)" \
  gin_seed_clean 273
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG14D="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG14D" ] && grep -qF "GATE-RECORD: PRE-WRITTEN $GIN_CHANGED" "$LG14D"; then
  ok "an ABBREVIATED skill-commit equal to theirs is still refused — the runner peels the recorded value rather than comparing header strings"
else
  bad "an abbreviated skill-commit defeated the equality guard (rc=$rc). '${SR_SKILL_COMMIT:-<short>}' and the full sha name one commit; comparing them as text acquits the post-write re-run"
fi
gin_restore

# --- Part G15: a FORGED record naming inputs of its author's choosing -------------------------
# The record cannot be trusted to declare its own coverage. A single input line satisfies any
# "at least one line" rule, so the required set is DERIVED from the consumer's own hook and the
# scripts it names — both sides of that join come from the same file, and neither is authored.
gin_restore
gin_seed "$(printf '# input: %s\t%s\t-' "$SR_PROBE_REL" "$(git hash-object "$GCONS/$SR_PROBE_REL" 2>/dev/null)")" 280
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG15="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG15" ] && grep -qF "GATE-RECORD: INPUT-MISSING" "$LG15" \
   && grep -qF "$GIN_CHANGED" "$LG15"; then
  ok "a record naming ONE input of its author's choosing is refused: the required set is derived from the consumer's own pre-push hook, and the missing gating scripts are named"
else
  bad "a forged single-line record authorised the cycle (rc=$rc). A reader that trusts the record's own input list can be satisfied by any one line — the coverage has to be derived from the hook, which is the same file the gate derives it from"
fi

# --- Part G16: a `-` row may name ONE core path, and it is the fallback hook -------------------
# Column 1 `-` means "read from the distribution", which exists for exactly one file: the
# fallback hook a consumer without its own cannot name in consumer-relative form. Left
# unconstrained it is an aim-anywhere primitive — a record could point the reader at any
# distribution file that happens to be stable and satisfy its own comparison.
gin_restore
gin_seed "$(printf -- '# input: -\t%s\tcore/scripts/machinery.sh\n%s' \
  "$(git -C "$DIST" rev-parse -q --verify "${D_THEIRS}:core/scripts/machinery.sh" 2>/dev/null)" \
  "$(sr_required_inputs "$GCONS")")" 290
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG16="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG16" ] && grep -qF "GATE-RECORD:" "$LG16" \
   && grep -qF "core/git-hooks/pre-push" "$LG16"; then
  ok "a distribution-side row naming a core path OTHER than the fallback hook is refused, and the message names the one path that spelling is for"
else
  bad "a \`-\` row naming an arbitrary distribution file was accepted (rc=$rc). That spelling exists for the fallback hook alone; unconstrained it lets a record choose which file its own comparison reads"
fi

# --- Part G17: the slice ADDING a file the pull ships is accepted ------------------------------
# The acquittal for the ABSENT direction, and it is what stops Part G9 from passing for a reader
# that refuses every arrival. A script the hook names, absent when the gate ran, present now with
# exactly the content this pull ships, is the slice — one property from G9's third-hand arrival.
gin_restore
gin_seed "$(printf '# input: %s\tABSENT\tcore/scripts/machinery.sh\n%s' \
  "scripts/ai-dlc/machinery.sh" "$(sr_required_inputs "$GCONS")")" 295
mkdir -p "$GCONS/scripts/ai-dlc"
git -C "$DIST" show "${D_THEIRS}:core/scripts/machinery.sh" > "$GCONS/scripts/ai-dlc/machinery.sh" 2>/dev/null
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG17="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG17" ] && grep -qF "===== FIXTURE green-one =====" "$LG17" \
   && ! grep -qF "GATE-RECORD:" "$LG17"; then
  ok "a path recorded ABSENT and now holding exactly what this pull SHIPS is the slice adding it, and is accepted — G9's refusal is keyed on the content, not on the arrival"
else
  bad "the slice ADDING a file the pull ships was refused (rc=$rc). Then Part G9 passes for a reader that refuses every arrival, and a pull delivering a new gating script wedges"
fi
rm -f "$GCONS/scripts/ai-dlc/machinery.sh"

# --- Parts G18 to G21: the digest column must be LOAD-BEARING ---------------------------------
# ARM 2 accepts an input whose content is now the `theirs` blob, because that is the slice this
# cycle wrote. Taken alone that makes the RECORDED digest decorative: after the write EVERY
# gating script is at `theirs`, so a record whose digests were never read off anything passes.
# Measured on the shipped arm — an all-zero forgery naming the derived required set returned
# rc=0, against a control with one script at a third-hand blob which correctly returned rc=2.
#
# The repair is that a recorded digest differing from `now` must be a content the path actually
# CARRIED in the range: its blob at BASE, or at any commit in `base..theirs` that touches it.
# G21 is why that set is not narrowed to "the base blob" — a split stamp legitimately leaves the
# consumer holding an intermediate release's blob.
#   G18  an all-zero forgery, consumer at theirs   the arm's own subject
#   G19  a decoy digest on the `-` row             the fallback hook always matches theirs
#   G20  the honest normal order                   the acquittal, re-asserted after the narrowing
#   G21  a consumer at an INTERMEDIATE blob        the acquittal a base-only rule would refuse

# --- Part G18: a record whose digests were never read off anything ----------------------------
# The required set is NAMED in full, so arm 1 is satisfied and cannot be what refuses; every
# digest is forty zeroes. The consumer is post-slice, which is the state that makes the forgery
# work: `now` equals `theirs` for the changed script, so a bare theirs-acceptance passes it.
gin_restore
gin_write_slice
gin_seed "$(printf '# input: .githooks/pre-push\t%s\t-\n# input: %s\t%s\tcore/scripts/gate-changed.sh\n# input: %s\t%s\tcore/scripts/gate-steady.sh' \
  "$(git hash-object "$GCONS/.githooks/pre-push")" \
  "$GIN_CHANGED" "$GZERO" "$GIN_STEADY" "$GZERO")" 400
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG18="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG18" ] && grep -qF "GATE-RECORD: INPUT-MOVED $GIN_CHANGED" "$LG18" \
   && grep -qF "is not a content this path carried anywhere" "$LG18"; then
  ok "a record whose digests are content this path NEVER carried is refused, though every file is at theirs — the digest column stays load-bearing after the slice is written"
else
  bad "an all-zero-digest record naming the full required set authorised the cycle (rc=$rc). After the write every gating script IS at theirs, so accepting on that alone makes the recorded digest decorative and a forged record indistinguishable from a gate's"
fi
gin_restore

# --- Part G19: a DECOY digest on the distribution-side row ------------------------------------
# The `-` row's file is the distribution's own copy, which the reader resolves under $DIST — so
# `now` equals the theirs blob by construction on every run, and a theirs-acceptance there would
# accept any digest at all. The slice never writes that file, so strict equality costs nothing.
# The consumer here has NO hook of its own, which is the only state that produces a `-` row.
GH="$(bash "$HERE/seed.sh")"
rm -rf "$GH/.githooks"
GHLOG="$GH/_bmad-output/ai-dlc-update"
mkdir -p "$GHLOG"
SR_INPUTS="$(printf -- '# input: -\t%s\tcore/git-hooks/pre-push\n# input: %s\tABSENT\tcore/scripts/machinery.sh' \
  "$GZERO" "scripts/ai-dlc/machinery.sh")" \
  seed_record "$GHLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 410 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G19's decoy record"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GH" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG19="$(ls -t "$GHLOG"/self-update-fixtures-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 2 ] && [ -n "$LG19" ] && grep -qF "INPUT-MOVED" "$LG19" \
   && grep -qF "distribution fallback hook" "$LG19"; then
  ok "a decoy digest on the distribution-side row is refused: that row is compared STRICTLY, because its file is the one the reader itself resolves"
else
  bad "a decoy digest on the \`-\` row was accepted (rc=$rc). The fallback hook's file IS the distribution's copy, so it equals the theirs blob on every run — a theirs-acceptance there accepts forty zeroes as readily as a real digest"
fi
# The ACQUITTAL for the same row, one property apart: the true digest must pass, or the arm
# above would be satisfied by a reader that refuses every `-` row.
SR_INPUTS="$(printf -- '# input: -\t%s\tcore/git-hooks/pre-push\n# input: %s\tABSENT\tcore/scripts/machinery.sh' \
  "$(git hash-object "$DIST/core/git-hooks/pre-push" 2>/dev/null)" "scripts/ai-dlc/machinery.sh")" \
  seed_record "$GHLOG" "$DIST" "$D_BASE" "$D_THEIRS" OK 411 >/dev/null
rm -f "$GHLOG"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GH" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG19B="$(ls -t "$GHLOG"/self-update-fixtures-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ -n "$LG19B" ] && grep -qF "===== FIXTURE green-one =====" "$LG19B"; then
  ok "...and the row's TRUE digest is accepted, so the refusal above is about the digest and not about the \`-\` spelling"
else
  bad "the distribution-side row was refused with its true digest (rc=$rc). A consumer with no hook of its own would then be refused on every self-update, forever"
fi
rm -rf "$GH"

# --- Part G20: the honest normal order still passes, after the narrowing ----------------------
# Re-asserted here rather than left to Part G6 because the conjunct added for G18 is the one
# thing that could refuse it: the recorded digest is the pre-write content, which must be found
# in the range's history for this path.
gin_restore
gin_seed_clean 420
gin_write_slice
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG20="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG20" ] && grep -qF "===== FIXTURE green-one =====" "$LG20" \
   && ! grep -qF "GATE-RECORD:" "$LG20"; then
  ok "the honest normal order still passes with the carried-content conjunct in place — the pre-write digest IS a content the path carried at base"
else
  bad "the narrowing added for Part G18 refused the legitimate flow (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG20" 2>/dev/null | cut -c1-150). A conjunct that refuses the honest case wedges every self-update, which is worse than the forgery it prevents"
fi
gin_restore

# --- Part G21: a consumer holding an INTERMEDIATE release's blob ------------------------------
# The acquittal a base-only rule would refuse, and the reason the carried-content set is derived
# from `git log` rather than from BASE alone. A split stamp — `skill_commit` ahead of `commit` —
# leaves the consumer at some release BETWEEN base and theirs, which is the normal state after
# any self-update and one this cycle itself creates. Its own three-commit distribution, because
# the shared one has no intermediate commit touching a gating script.
build_i_world
# THE SEED IS ASSERTED TO DISCRIMINATE. Three distinct blobs are what make "carried in the
# range" and "equals the base blob" different answers; where mid equals base or theirs the arm
# below passes for either implementation.
if [ -n "$I_MB" ] && [ "$I_MB" != "$I_BB" ] && [ "$I_MB" != "$I_TB" ]; then
  ok "SEED: the intermediate release's blob differs from BOTH base and theirs, so 'carried anywhere in the range' and 'equals the base blob' give different answers"
else
  bad "FIXTURE ERROR: the intermediate seed's three blobs are not distinct (base ${I_BB:-none}, mid ${I_MB:-none}, theirs ${I_TB:-none}). Part G21 would then pass for a base-only rule and the narrowing is untested"
fi
I_K="$(mktemp -d)"; sufl_tmp "$I_K"
mkdir -p "$I_K/_bmad-output/ai-dlc-update" "$I_K/tests/fixtures/probe" "$I_K/.githooks" "$I_K/scripts/ai-dlc"
printf 'exit 0\n' > "$I_K/tests/fixtures/probe/run.sh"
printf 'bash scripts/ai-dlc/gate-changed.sh\n' > "$I_K/.githooks/pre-push"
# The consumer sits at MID when the gate runs — the split-stamp state.
IG show "${I_M}:core/scripts/gate-changed.sh" > "$I_K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
printf '# base-sha: %s\n# theirs-sha: %s\n# input: .githooks/pre-push\t%s\t-\n# input: scripts/ai-dlc/gate-changed.sh\t%s\tcore/scripts/gate-changed.sh\n\n# verdict: OK\n' \
  "$I_B" "$I_T" "$(git hash-object "$I_K/.githooks/pre-push")" "$I_MB" \
  > "$I_K/_bmad-output/ai-dlc-update/self-update-gate-19700101T000000Z.md"
# ...and then the slice is written, exactly as step 2 writes it.
IG show "${I_T}:core/scripts/gate-changed.sh" > "$I_K/scripts/ai-dlc/gate-changed.sh" 2>/dev/null
bash "$RUNNER" "$I_D" "$I_B" "$I_T" "$I_K" probe >/dev/null 2>&1
rc=$?
LG21="$(ls -t "$I_K"/_bmad-output/ai-dlc-update/self-update-fixtures-*.md 2>/dev/null | head -1)"
if [ "$rc" -eq 0 ] && [ -n "$LG21" ] && ! grep -qF "GATE-RECORD:" "$LG21"; then
  ok "a consumer whose pre-write copy was an INTERMEDIATE release's blob is accepted — the carried-content set is every blob the path held in the range, not the base blob alone"
else
  bad "a split-stamp consumer at an intermediate release's blob was refused (rc=$rc): $(grep -m1 '^GATE-RECORD:' "$LG21" 2>/dev/null | cut -c1-150). That is the normal state after any self-update and one this cycle itself creates, so narrowing the accepted set to the base blob wedges those consumers"
fi

# --- Part G22: a base gate that DECLARES the record directory and never writes ----------------
# ARM 4's token has to spell the WRITE, not an assignment. Keyed on `GATE_REC_DIR` it scores 1
# on a locally patched old gate that declares the variable and never writes — converting a local
# edit into a refusal whose message says the records were deleted. The composed filename cannot
# be present without the write.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE_DECL" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG22="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG22" ] && grep -qF "GATE-RECORD: NOT-REQUIRED" "$LG22"; then
  ok "a base gate that DECLARES the record directory and never writes is read as non-recording — the token spells the write site, not an assignment"
else
  bad "a gate declaring GATE_REC_DIR without writing was read as a recording gate (rc=$rc), so an empty directory becomes a refusal saying the records were deleted. A local edit that adds the variable then wedges the consumer with a message about a state that never happened"
fi

# --- Part G23: a RECORDING gate whose write site was reflowed is still read as recording -------
# The mirror of G22. G22 guards against a token that OVER-fires (an assignment read as a write);
# this guards against one that UNDER-fires, and under-firing here is the acquittal: the records
# deleted on such a consumer would otherwise reach NOT-REQUIRED and waive the requirement.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE_REFLOW" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG23="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG23" ] && grep -qF "GATE-RECORD: MISSING" "$LG23" \
   && ! grep -qF "NOT-REQUIRED" "$LG23"; then
  ok "a base gate that RECORDS through a reflowed write site is still read as recording, so deleted records are refused as MISSING — the token spells the composed filename, which no reflow removes"
else
  bad "a recording gate whose write site was reflowed was read as NON-recording (rc=$rc), so an operator who deleted the records reached NOT-REQUIRED and the whole requirement was waived. The probe token is keyed on one author's exact spelling of the write, and the acquitting direction is the one that must not fail"
fi

# --- Parts G12 and G13: the DELIVERY-PULL tolerance, and the state it must NOT cover -----------
# A fix to a bootstrapping step can never be delivered by that step. On the pull that DELIVERS
# this requirement the OLD gate runs and records nothing, the slice installs this runner, and a
# hard refusal blocks the self-update carrying the fixed gate — with step 2 requiring green
# before the push, that pull can never land. Measured on the reference consumer: 69 of 87
# self-update commits wrote some `reconcile/` file and 3 wrote this runner, against a control of
# 0 of 87 for an impossible path.
#
# THE EXEMPTION IS KEYED ON THE GATE THE CONSUMER HAD, READ FROM THE DISTRIBUTION AT BASE — not
# on the record directory being empty, which `rm -f` reaches at will. G13 is the probe that it
# does not cover the arm's own subject.

# --- Part G12: no record, and the gate at BASE could not have recorded -------------------------
# `$D_BASE`'s gate carries no record-writing site, so this is the delivery pull.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
ERRG12="$GCONS/err-g12.txt"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>"$ERRG12"
rc=$?
LG12="$(newest_glog)"
if [ "$rc" -eq 0 ] && [ -n "$LG12" ] && grep -qF "GATE-RECORD: NOT-REQUIRED" "$LG12" \
   && grep -qF "===== FIXTURE green-one =====" "$LG12"; then
  ok "no record, and the gate at BASE carries no record-writing site: the run proceeds with NOT-REQUIRED — the pull that delivers recording can still land"
else
  bad "a consumer whose installed gate could not have recorded was refused (rc=$rc). The old gate writes no record, so this is the state of the very pull that installs the recording one; refusing it means the fix can never be delivered by the step that delivers it"
fi
if grep -qF "NOT-REQUIRED" "$ERRG12"; then
  ok "the tolerance is announced on stderr too, so a green run does not silently omit the check"
else
  bad "the run proceeded on the tolerance and said so only in the log. A skipped requirement that reports nothing to the operator's channel reads exactly like one that passed"
fi

# --- Part G13a: records DELETED, with a RECORDING gate at base, still refuses ------------------
# The input an emptiness test cannot see, and the one the adversary reached with `rm -f`. Same
# empty directory as Part G12; the only thing different is which gate the consumer had, which is
# read out of the distribution where a deletion on the consumer cannot touch it.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
bash "$RUNNER" "$DIST" "$D_BASE_REC" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG13A="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG13A" ] && grep -qF "GATE-RECORD: MISSING" "$LG13A" \
   && ! grep -qF "NOT-REQUIRED" "$LG13A"; then
  ok "an EMPTY record directory with a RECORDING gate at base is refused as MISSING — the tolerance reads which gate the consumer had, not whether the directory happens to be empty"
else
  bad "deleting the records reached the tolerance (rc=$rc). \`rm -f self-update-gate-*.md\` is then the whole bypass, and the requirement is advisory for anyone willing to run it"
fi

# --- Part G13b: ONE record, for a DIFFERENT range, still refuses ------------------------------
# A consumer that HAS recorded a verdict, just not for this range. That is the ordinary
# post-first-cycle state, and an exemption widened to "no record for THIS range" acquits all of them.
gin_restore
rm -f "$GLOG"/self-update-gate-*.md "$GLOG"/self-update-fixtures-*.md
seed_record "$GLOG" "$DIST" "$D_QUIET" "$D_SHIP" OK 260 >/dev/null \
  || bad "FIXTURE ERROR: could not seed Part G13b's wrong-range record"
bash "$RUNNER" "$DIST" "$D_BASE" "$D_THEIRS" "$GCONS" touched-shippable touched-named green-one \
  >/dev/null 2>&1
rc=$?
LG13="$(newest_glog)"
if [ "$rc" -eq 2 ] && [ -n "$LG13" ] && grep -qF "GATE-RECORD:" "$LG13" \
   && ! grep -qF "NOT-REQUIRED" "$LG13"; then
  ok "with ONE record present, for a DIFFERENT range, the requirement still binds — the tolerance covers a consumer whose gate could not record, not a range that has not been classified"
else
  bad "a consumer holding a record for another range was let through on the delivery-pull tolerance (rc=$rc). That is the ordinary state after the first cycle, so this widening acquits every subsequent self-update and the exemption defends the defect the arm exists for"
fi

# --- Part 20: A BLOB-FILTERED $DIST MUST NOT CONVICT A CORRECT SET ---------------------------
# `git cat-file -e <rev>:<path>` requires the BLOB OBJECT locally. On a `--filter=blob:none`
# clone whose promisor is unreachable it answers ABSENT for a path that exists, so BOTH probes
# fail: the over-completeness arm convicts every named directory, and the under-completeness
# join silently reports nothing having compared nothing. `rev-parse -q --verify` resolves through
# the TREE and needs no blob.
#
# THE GUARDS ABOVE CANNOT COVER THIS, WHICH IS WHY IT NEEDS ITS OWN ARM. `${THEIRS}:core/fixtures`
# is a TREE, and trees are not filtered — it resolves fine, so both the ref-resolution loop and
# the wrong-repo guard pass and hand the arm a repo it cannot read.
#
# BOTH DIRECTIONS, ONE RUN, and the probe is only believed once it is shown to DISCRIMINATE: the
# arm below refuses to score unless the filtered clone is genuinely missing objects and the two
# spellings disagree on a path that exists while agreeing on one that does not.
# PART 20 BUILDS ITS OWN SOURCE REPO RATHER THAN CLONING `$DIST`, and the reason is a null this
# arm produced on its first run. Git blobs are CONTENT-ADDRESSED, and `$DIST`'s seed writes the
# same two strings into every file — so every historical blob collapses onto an object the
# checkout already holds, a filtered clone is missing nothing, and the arm correctly reported
# SKIP. Here every version of every file is UNIQUE, so the base-side blobs are genuinely absent
# from a `blob:none` checkout and the two spellings can disagree.
build_filt_world
if [ -d "$FILT/.git" ]; then
  if ! filt_ok; then
    ok "SKIP: this git/transport did not produce a DISCRIMINATING blob-filtered clone (missing=$f_missing, cat-file=$f_cat, rev-parse=$f_rev, control=$f_ctl) — reporting that rather than scoring a null the probe could not have failed"
  else
    # The OVER arm. `theirs` is the HISTORICAL `filt-theirs`, never the tip: the named set is
    # wholly shippable there, and its blobs are the ones the filter left out. Both dirs are named,
    # so the under-completeness join is satisfied and this run scores the over-arm alone.
    rm -f "$LOGDIR2"/self-update-fixtures-*.md
    bash "$RUNNER" "$FILT" "$f_base" filt-theirs "$CONS2" keeper mover >/dev/null 2>&1
    rc=$?
    if [ "$rc" -ne 2 ] || [ -z "$(uns_set "$(newest_log2)")" ]; then
      ok "a blob-filtered \$DIST does not convict a correct set — the probes resolve through the TREE, and a filtered blob is not a missing path"
    else
      bad "a blob-filtered \$DIST convicted a wholly shippable set (rc=$rc, refused '$(uns_set "$(newest_log2)")'). The probes are reading BLOBS: \`cat-file -e\` answers ABSENT for a filtered object and the arm indicts correct input"
    fi
    # ...and the UNDER-completeness join must still find its subject on the same clone. There the
    # same defect is SILENT: both exemption probes fail, every diff-touched dir takes `|| continue`,
    # `uncovered` stays empty, and the join reports nothing having compared nothing.
    rm -f "$LOGDIR2"/self-update-fixtures-*.md
    bash "$RUNNER" "$FILT" "$f_base" filt-theirs "$CONS2" keeper >/dev/null 2>&1
    if [ "$(cov_set "$(newest_log2)")" = "mover," ]; then
      ok "...and on the same clone the under-completeness join still names its subject — the silent half of the same defect is repaired too"
    else
      bad "on a blob-filtered \$DIST the under-completeness join reported '$(cov_set "$(newest_log2)")' instead of 'mover,'. Its exemption probes are reading BLOBS, so every diff-touched dir is skipped and an incomplete set passes over an empty comparison"
    fi
  fi
  rm -rf "$FILT_ROOT"
else
  rm -rf "$FILT_ROOT"
  ok "SKIP: could not build a blob-filtered clone here — reporting that rather than scoring a null"
fi

# --- PARTS J1 to J14: EVERY VERDICT THE GATE CAN WRITE MUST HAVE A SKILL BULLET CLAIMING ----
# ---                  THE RECORD IT WROTE                                                 ----
#
# THE DEFECT. `self-update-gate.sh` writes `_bmad-output/ai-dlc-update/self-update-gate-<ts>.md`
# on EVERY verdict -- `gate_record_open()` is guarded by `AI_DLC_GATE_IN_SAFE_STOP` and by
# nothing else, never by the verdict -- and step 2's only instruction naming that record used to
# sit on the OK path, where it names the record and the fixture log as a PAIR and sends both to a
# self-update commit the DEFER path never creates. So the DEFER and UNDECIDED paths wrote an
# approval record no step claimed. Filed by the reference consumer as
# PC-S345, and the operator had been committing that record by hand on the step-7 reconcile.
#
# BOTH SIDES ARE DERIVED, WHICH IS WHAT MAKES THIS AN OBSERVATION RATHER THAN A RESTATEMENT OF
# THE RECEIPT THAT SHIPPED WITH IT. Side A is the gate's own `_rec_v=` assignments; side B is the
# region of `SKILL.md` belonging to each verdict's disposition bullet. Neither is hand-listed, so
# a fourth verdict added to the gate with no bullet fires this arm on its own.
#
# THE SPAN GRAMMAR WAS CHOSEN BY MEASUREMENT AND THE OBVIOUS ONE IS WRONG. A region running to
# the next SIBLING bullet (`^   - `) scores the OK path at ZERO on the fixed tree as well as the
# broken one: the OK bullet is a ONE-LINE bullet and the passage naming the record sits thirty
# lines below it, inside the CARRY bullet's span under that grammar. An arm keyed on it would
# fail the push on a correct tree. Measured at both revisions, per bullet. The grammar that
# discriminates runs each region to the next DISPOSITION bullet (`^   - On \`SELF-UPDATE-`), else
# to the end of the numbered step: base scores 1 of 3 verdicts claimed, the fix scores 3 of 3.
#
# ONE BULLET COVERS TWO VERDICTS, so the join is over VERDICTS and never over bullet COUNT. The
# DEFER bullet opens `On \`SELF-UPDATE-DEFER\` or \`SELF-UPDATE-UNDECIDED\``; a count comparison
# reads three bullets against three verdicts and passes vacuously on a tree where the UNDECIDED
# path is claimed by nothing.
#
# THE REGION IS READ WITH FENCED BLOCKS AND HTML COMMENTS BLANKED, AND THE COMMIT-VERB SCAN IS
# READ WITH INLINE CODE SPANS REMOVED ON TOP OF THAT. A comment is not an instruction and a
# fenced example is not one either (mutants J11 and J13). The code-span strip is the narrowing
# that took this arm's false-positive set to zero: `skill_commit` and `version`/`commit` are
# FIELD NAMES, the DEFER bullet at base carries `skill_commit` and nothing else, and without the
# strip the unfixed tree scores its DEFER region as claimed. The record TOKEN is counted BEFORE
# the strip, because the record's path is itself written inside a code span.
#
# THE NEGATION SCAN IS READ WITH THE DISCLAIMER CLAUSE EXCISED, and that subtlety is the one a
# naive scan gets backwards: the correct fix's own disclaimer says `nothing in \`reconcile/\`
# stages or commits anything`, so a scan that discards any line carrying a negation discards the
# fix. The exclusion is anchored on the negation reaching a commit verb within one sentence.
#
# THE FALSE-REJECT SET WAS MEASURED, NOT ASSUMED. Four competent alternate phrasings of the same
# correct fix, written without reference to this predicate, all score CLAIMED (J7 to J10). A
# receipt that rejects a competent author's other wording is as broken as one that accepts a
# regression, and the receipt this arm was built beside rejected 3 of 6.
#
# THE SUBJECT CAN BE ABSENT ON A CONSUMER AND THAT MUST NOT READ AS A PASS. This fixture SHIPS,
# a core fixture arrives one pull ahead of the code it guards, and a shipping arm whose subject
# is missing stands down -- which scores as a green unit in the consumer's own suite verdict.
# So the resolve is the same dual-layout `pick()` this file already uses for the runner, both
# candidates named side by side and never a walk up from a resolved path (I33) nor a walk for
# VERSION (I106), and a missing subject prints a SKIP line that is not an `ok`.
J_SKILL="$(pick "$HERE/../../skills/ai-dlc-update/SKILL.md" \
                "$HERE/../../../core/skills/ai-dlc-update/SKILL.md" \
                "$HERE/../../../.claude/skills/ai-dlc-update/SKILL.md")"
J_GATE="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/self-update-gate.sh" \
               "$HERE/../../../core/skills/ai-dlc-update/reconcile/self-update-gate.sh" \
               "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/self-update-gate.sh")"

JW="$(mktemp -d)"
sufl_tmp "$JW"

# The reader, in one place so the probe, the corpus and every mutant below score under the
# identical grammar. It prints one line per verdict the gate can write whose SKILL.md region
# does NOT claim the record, and nothing at all when every verdict is claimed.
j_unclaimed() { # $1=a SKILL.md  $2=a gate script -> one unclaimed verdict per line
  j_s="$JW/stripped.$$"
  # Fenced blocks and HTML comments blanked, LINE NUMBERING PRESERVED -- deleting the lines
  # instead would shift every region boundary below a fence and the offsets would be about a
  # file nobody reads.
  awk '
    /^```/ { fence = !fence; print ""; next }
    fence  { print ""; next }
    /<!--/ { incom = 1 }
    incom  { if (index($0, "-->")) incom = 0; print ""; next }
    { print }
  ' "$1" > "$j_s"
  j_verdicts="$(grep -oE '_rec_v=[A-Za-z][A-Za-z0-9_-]*' "$2" | sed 's/.*=//' | sort -u)"
  j_disp="$(grep -nE '^   - On `SELF-UPDATE-' "$j_s" | cut -d: -f1)"
  j_first="$(printf '%s\n' "$j_disp" | head -1)"
  j_end="$(grep -nE '^[0-9]+\. ' "$j_s" | awk -F: -v f="$j_first" '$1 > f { print $1 - 1; exit }')"
  [ -n "$j_end" ] || j_end="$(wc -l < "$j_s")"
  for j_v in $j_verdicts; do
    j_bl="$(grep -nE "^   - On \`SELF-UPDATE-${j_v}\`|^   - On \`SELF-UPDATE-[A-Z-]+\`( or \`SELF-UPDATE-[A-Z-]+\`)* or \`SELF-UPDATE-${j_v}\`" \
            "$j_s" | head -1 | cut -d: -f1)"
    [ -n "$j_bl" ] || { printf '%s\n' "$j_v"; continue; }
    j_re="$(printf '%s\n' "$j_disp" | awk -v b="$j_bl" '$1 > b { print $1 - 1; exit }')"
    [ -n "$j_re" ] || j_re="$j_end"
    j_reg="$(sed -n "${j_bl},${j_re}p" "$j_s")"
    j_rec="$(printf '%s\n' "$j_reg" | grep -cF 'self-update-gate-')" || j_rec=0
    j_pos="$(printf '%s\n' "$j_reg" | sed 's/`[^`]*`/@/g' | grep -E 'commit(s|ted|ting)?' \
             | grep -cviE '(do not|never|nothing[^.]*)[^.]*commit')" || j_pos=0
    { [ "$j_rec" -gt 0 ] && [ "$j_pos" -gt 0 ]; } || printf '%s\n' "$j_v"
  done
  rm -f "$j_s"
}
j_flat() { j_unclaimed "$1" "$2" | sort | tr '\n' ',' ; }

if [ -z "$J_SKILL" ] || [ -z "$J_GATE" ]; then
  # DISTINGUISHABLE, AND DELIBERATELY NOT AN `ok`. This is the mid-pull state: the fixture has
  # landed and its subject has not. `bad` would wedge the consumer's push on a state the pull
  # itself creates; silence would let a unit that checked nothing count toward a green suite.
  printf '  SKIP  the verdict/record join: no ai-dlc-update %s resolves from %s in either layout, so this fixture landed ahead of its subject and asserted nothing here\n' \
    "$([ -z "$J_SKILL" ] && printf 'SKILL.md' || printf 'reconcile/self-update-gate.sh')" "$HERE"
else
  # --- J1 and J2: THE SELF-PROBE, BOTH DIRECTIONS, UNDER mktemp AND BEFORE THE CORPUS --------
  # An arm reporting zero findings without first proving it can produce one has established that
  # it ran. The offender is a tree whose DEFER region names no record; the near-miss is the same
  # tree with a correct fix written in a phrasing this predicate was not built around.
  J_OFF="$JW/probe-offender.md"
  awk '!/^     \*\*The gate wrote `_bmad-output/ &&
       !/^     Carry that record to the step-7 gated apply/ &&
       !/^     \*\*That is an instruction to the operating agent/ &&
       !/^     `reconcile\/` stages or commits anything/ &&
       !/^     agent put it there\.$/' "$J_SKILL" > "$J_OFF"
  J_NEAR="$JW/probe-near-miss.md"
  awk '{ print }
       /^     runs and the flag is what tells them apart/ {
         print "     The gate already wrote `_bmad-output/ai-dlc-update/self-update-gate-<ts>.md` for this"
         print "     verdict; include it in the step-7 gated apply commit alongside the machinery slice." }' \
    "$J_OFF" > "$J_NEAR"
  j_off_flat="$(j_flat "$J_OFF" "$J_GATE")"
  j_near_flat="$(j_flat "$J_NEAR" "$J_GATE")"
  # The offender must have been CONSTRUCTIBLE. A probe built by a pattern that matched nothing is
  # byte-identical to the subject, and an arm that then reports nothing reads exactly like one
  # that discriminates.
  if cmp -s "$J_SKILL" "$J_OFF" || cmp -s "$J_OFF" "$J_NEAR"; then
    bad "FIXTURE ERROR: the J probe trees did not build (offender identical to the subject, or the near-miss identical to the offender). Neither direction of this reader was proven this run, so its verdict on the real corpus says only that it ran"
  elif [ -n "$j_off_flat" ] && [ -z "$j_near_flat" ]; then
    ok "the verdict/record reader REPORTS a seeded offender (a DEFER region naming no record: ${j_off_flat}) and stays QUIET on a seeded near-miss written in a phrasing it was not built around — both directions, on trees under mktemp and never the real corpus"
  else
    bad "the verdict/record reader did not discriminate on its own probe trees (offender read '${j_off_flat:-empty}' and must be non-empty; near-miss read '${j_near_flat:-empty}' and must be empty). An empty offender reading is a reader that cannot spell its own subject; a non-empty near-miss reading is one that rejects a correct fix, which is the defect one row above this one in the same worklist"
  fi

  # --- J3: THE INSTRUMENT ITSELF, before any verdict is read off it --------------------------
  # A derived population of zero on either side reports a clean join having joined nothing.
  j_na="$(grep -oE '_rec_v=[A-Za-z][A-Za-z0-9_-]*' "$J_GATE" | sed 's/.*=//' | sort -u | grep -c .)" || j_na=0
  j_nb="$(grep -cE '^   - On `SELF-UPDATE-' "$J_SKILL")" || j_nb=0
  j_ctl="$(grep -cF 'self-update-gate-ZZQX139' "$J_SKILL")" || j_ctl=0
  j_tok="$(grep -cF 'self-update-gate-' "$J_SKILL")" || j_tok=0
  if [ "$j_na" -ge 2 ] && [ "$j_nb" -ge 1 ] && [ "$j_ctl" -eq 0 ] && [ "$j_tok" -gt 0 ]; then
    ok "both sides of the join derive a non-empty population ($j_na gate verdicts, $j_nb disposition bullets) and the record token scores $j_tok against an impossible-token control of 0 in the same file"
  else
    bad "the join's own instrument is broken (gate verdicts $j_na expected >=2, disposition bullets $j_nb expected >=1, impossible-token control $j_ctl expected 0, record token $j_tok expected >0). A side that derives nothing reports every verdict claimed, or every verdict unclaimed, for a reason that is not about the tree"
  fi

  # --- J4: THE CORPUS ------------------------------------------------------------------------
  j_live="$(j_flat "$J_SKILL" "$J_GATE")"
  if [ -z "$j_live" ]; then
    ok "every verdict \`self-update-gate.sh\` can write has a step-2 disposition region instructing that the record it wrote be committed — the gate records on every verdict, so a verdict whose bullet names no record leaves an approval artifact no step claims"
  else
    bad "these verdicts the gate CAN write have no disposition region instructing that the record be committed: ${j_live}. \`gate_record_open()\` is guarded by AI_DLC_GATE_IN_SAFE_STOP and by nothing else, so the record exists on every one of them; the operator then either loses it or commits it by hand. Name the record ALONE in that verdict's bullet — not as the 'approval artifact', which SKILL.md defines as a PAIR — and name the step-7 gated apply as its destination, never the self-update commit, which the DEFER path never creates"
  fi

  # --- J5 to J13: THE MUTATION BATTERY ------------------------------------------------------
  # Every mutant is a COPY under mktemp, `cmp -s` asserts it applied before its score is read,
  # and each is keyed on a LOCATION and an observable rather than on a spelling. A mutation that
  # did not apply reads exactly like one that survived.
  j_mut() { # $1=label $2=mutant path $3=original it was built from $4=want-flat $5=why
    if [ ! -s "$2" ] || cmp -s "$3" "$2"; then
      bad "MUTATION $1 DID NOT APPLY (the anchor no longer occurs in ${3##*/}), so it scores nothing. Re-anchor it on the subject's own predicate; a lost anchor must never be repaired by relaxing an assertion"
      return
    fi
    j_got="$(j_flat "$2" "$J_GATE")"
    if [ "$j_got" = "$4" ]; then
      ok "MUTATION $1 — $5"
    else
      bad "MUTATION $1 SURVIVED or fired wrongly: the reader returned '${j_got:-empty}' and must return '${4:-empty}'. $5"
    fi
  }

  # J5: the fix REVERTED. Every layer of it, and the post-mutation token count is asserted to
  # have dropped -- a mutation that applies can still be partial, and `cmp -s` cannot see that.
  J_M1="$J_OFF"
  j_m1_tok="$(grep -cF 'self-update-gate-' "$J_M1")" || j_m1_tok=0
  if [ "$j_m1_tok" -lt "$j_tok" ]; then
    j_mut "J5 fix reverted" "$J_M1" "$J_SKILL" "DEFER,UNDECIDED," \
      "reverting the whole insertion leaves the two verdicts that bullet covers claiming no record, which is the state this arm exists to refuse (token count fell $j_tok -> $j_m1_tok, so the revert was not partial)"
  else
    bad "MUTATION J5's revert was PARTIAL: the record token still scores $j_m1_tok against an unmutated $j_tok. A partial revert proves the layer left in place and comes out green"
  fi

  # J6: a FOURTH verdict in the GATE with no bullet. This mutates SIDE A, so it is the only
  # mutant here that establishes the verdict set is READ rather than assumed.
  J_M2="$JW/gate-4th.sh"
  awk '{ print }
       /^      _rec_v=UNDECIDED$/ { print "    elif false; then"; print "      _rec_v=STRANDED" }' \
    "$J_GATE" > "$J_M2"
  if [ -s "$J_M2" ] && ! cmp -s "$J_GATE" "$J_M2" && bash -n "$J_M2" 2>/dev/null; then
    j_got4="$(j_flat "$J_SKILL" "$J_M2")"
    if [ "$j_got4" = "STRANDED," ]; then
      ok "MUTATION J6 — a FOURTH verdict added to the gate with no bullet for it is reported, and the three that DO have one are not: the verdict set is read out of the script rather than hand-listed here, so this arm fires the day somebody adds a verdict"
    else
      bad "MUTATION J6 SURVIVED or over-fired: the reader returned '${j_got4:-empty}' and must return 'STRANDED,'. Empty means side A is not derived from the gate at all; anything extra means the addition perturbed a verdict it should not have touched"
    fi
  else
    bad "FIXTURE ERROR: MUTATION J6 did not build a parseable gate with a fourth verdict, so nothing established that side A is derived"
  fi

  # J7: the instruction MOVED out of the DEFER region to a place it does not belong -- below the
  # CARRY bullet, still inside step 2 and still in the file. The token count is UNCHANGED, so
  # only a region-keyed reader can see it; a whole-file grep cannot.
  J_M3="$JW/m-relocated.md"
  awk 'BEGIN { buf = "" }
       /^     \*\*The gate wrote `_bmad-output/ , /^     agent put it there\.$/ { buf = buf $0 "\n"; next }
       { print }
       /^   - `SELF-UPDATE-CARRY` rows are ADVISORY/ { printf "%s", buf; buf = "" }' \
    "$J_SKILL" > "$J_M3"
  j_m3_tok="$(grep -cF 'self-update-gate-' "$J_M3")" || j_m3_tok=0
  if [ "$j_m3_tok" -eq "$j_tok" ]; then
    j_mut "J7 instruction relocated" "$J_M3" "$J_SKILL" "DEFER,UNDECIDED," \
      "moving the instruction out of the DEFER region and into the CARRY bullet's leaves the whole-file token count UNCHANGED at $j_tok, so a file-wide grep reads the tree as fixed and only a region-keyed reader refuses it"
  else
    bad "FIXTURE ERROR: MUTATION J7 changed the whole-file token count ($j_tok -> $j_m3_tok), so it is not the relocation it claims to be and a kill would be scored on a deletion instead"
  fi

  # J8: the OK path's instruction deleted, DEFER's left intact. The join is over ALL verdicts,
  # and without this mutant nothing establishes that -- an arm that only ever looked at DEFER
  # would pass every run.
  J_M4="$JW/m-ok-deleted.md"
  awk '!/^   \*\*Commit BOTH files in the self-update commit\*\*/ &&
       !/^   `_bmad-output\/ai-dlc-update\/self-update-gate-<ts>\.md` — its verdict/' "$J_SKILL" > "$J_M4"
  j_mut "J8 OK instruction deleted" "$J_M4" "$J_SKILL" "OK," \
    "deleting the OK path's own record instruction while DEFER's stands is reported as OK alone — the join is over every verdict the gate can write, not over the one this batch fixed"

  # J9: an inert HTML COMMENT carrying the whole instruction. A comment is not an instruction,
  # and the raw token count is asserted UNCHANGED so the kill is the comment strip and not a
  # deletion.
  J_M5="$JW/m-comment.md"
  awk '/^     \*\*The gate wrote `_bmad-output/ { print "     <!-- " $0; incom = 1; next }
       incom && /^     agent put it there\.$/  { print $0 " -->"; incom = 0; next }
       { print }' "$J_SKILL" > "$J_M5"
  j_m5_tok="$(grep -cF 'self-update-gate-' "$J_M5")" || j_m5_tok=0
  if [ "$j_m5_tok" -eq "$j_tok" ]; then
    j_mut "J9 HTML-comment only" "$J_M5" "$J_SKILL" "DEFER,UNDECIDED," \
      "an instruction that survives only inside an HTML comment is refused, with the raw token count unchanged at $j_tok — the comment strip is what the kill is scored on"
  else
    bad "FIXTURE ERROR: MUTATION J9 changed the raw token count ($j_tok -> $j_m5_tok), so it deleted the passage rather than commenting it out and J5 already owns that case"
  fi

  # J10: the same instruction inside a FENCED code block. Its own mutant rather than a second
  # assertion on J9's seed: one strip can be present with the other absent, and a seed that
  # exercises both cannot say which strip fired.
  J_M6="$JW/m-fenced.md"
  awk '{ print }
       /^     runs and the flag is what tells them apart/ {
         print "```"
         print "commit _bmad-output/ai-dlc-update/self-update-gate-<ts>.md"
         print "```" }' "$J_OFF" > "$J_M6"
  j_mut "J10 fenced block only" "$J_M6" "$J_OFF" "DEFER,UNDECIDED," \
    "an instruction present only inside a fenced code block is refused too — the fence strip and the comment strip are separate properties and neither covers the other"

  # J11: a NEGATED instruction naming the record. The near-miss that carries every property the
  # arm keys on EXCEPT the one that matters, and the direction that looks finished: without it,
  # a reader satisfied by the record token alone passes.
  J_M7="$JW/m-negated.md"
  awk '{ print }
       /^     runs and the flag is what tells them apart/ {
         print "     The gate wrote `_bmad-output/ai-dlc-update/self-update-gate-<ts>.md` on this verdict."
         print "     Do not commit it; the operator disposes of it by hand." }' "$J_OFF" > "$J_M7"
  j_mut "J11 negated instruction" "$J_M7" "$J_OFF" "DEFER,UNDECIDED," \
    "a region that NAMES the record while forbidding the commit is still unclaimed — the record token alone does not satisfy this arm, and the disclaimer clause the correct fix carries (nothing in reconcile/ stages or commits anything) is excised rather than read as that negation"

  # J12 and J13: TWO COMPETENT ALTERNATE PHRASINGS of the same correct fix, each in its own
  # mutant and neither written from this predicate's accept-set. They must NOT fire. This is the
  # measured half of the false-positive set, and it is the half the receipt beside this arm got
  # wrong: it rejected 3 of 6 correct phrasings, which is BL-279's defect one row up.
  j_phrasing() { # $1=label $2=first line $3=second line
    j_p="$JW/m-phrase-$1.md"
    awk -v l1="$2" -v l2="$3" '{ print }
         /^     runs and the flag is what tells them apart/ { print l1; print l2 }' "$J_OFF" > "$j_p"
    if [ ! -s "$j_p" ] || cmp -s "$J_OFF" "$j_p"; then
      bad "MUTATION $1 DID NOT APPLY, so nothing was established about this arm's false-REJECT set"
      return
    fi
    j_pg="$(j_flat "$j_p" "$J_GATE")"
    if [ -z "$j_pg" ]; then
      ok "MUTATION $1 — a competent author's alternate phrasing of the SAME correct fix is ACCEPTED. An arm that rejects a correct fix wedges the work it exists to protect, and its false-REJECT set is the half that goes unmeasured"
    else
      bad "MUTATION $1 was REJECTED: the reader returned '${j_pg}' against a correctly-fixed region written in another wording. That is a false REJECT, and it is the defect filed one row above this one in the same worklist"
    fi
  }
  j_phrasing "J12 rephrasing (include-in)" \
    "     Include \`_bmad-output/ai-dlc-update/self-update-gate-<ts>.md\`, which the gate wrote here," \
    "     in the commit the step-7 gated apply makes."
  j_phrasing "J13 rephrasing (record-exists)" \
    "     A record exists at \`_bmad-output/ai-dlc-update/self-update-gate-<ts>.md\` even on this path," \
    "     and the operating agent commits it with the step-7 gated apply."

  # J14: THE UNMUTATED CONTROL, PRESENCE-SHAPED AND RUN LAST. Every arm above is
  # presence-shaped, so a reader replaced by `exit 0` fails them by construction -- but the
  # control still has to assert a positive: that the reader names the verdicts it was given and
  # not a fixed string. It is scored on the OFFENDER, where the answer is non-empty, because on
  # the real tree an empty answer is indistinguishable from a reader that returns nothing ever.
  j_ctl_off="$(j_unclaimed "$J_OFF" "$J_GATE" | sort | tr '\n' ' ')"
  case "$j_ctl_off" in
    *DEFER*UNDECIDED*)
      ok "CONTROL — the reader names the specific verdicts it found unclaimed ($j_ctl_off) rather than emitting a fixed string, so every kill above is the mutation and not a reader that answers the same way on any input" ;;
    *)
      bad "CONTROL — the reader did not name DEFER and UNDECIDED on the offender tree (got '${j_ctl_off:-empty}'). A reader whose output does not depend on its input scores every mutant above for a reason that is not the mutation" ;;
  esac
fi

# --- Part 21: AN UNREADABLE `.dist-only` IS A REFUSAL, NEVER AN ANSWER (BL-403) ---------------
# Both `.dist-only` probes are `memo_has_path` (lib.sh): 0 present, 128 CONFIRMED absent, 125 when
# git said no and the absence could not be confirmed. The probe they replaced, `rev-parse -q
# --verify`, answers 1 for an absent marker and for an unreadable subtree alike.
#
# TWO WORLDS, ONE PER SITE, because one missing object cannot reach both. At the OVER-arm the
# discriminating input is a named directory whose TREE at theirs is missing: the old probe read
# "not dist-only", then "no run.sh at theirs", and told the operator upstream deleted a driver it
# could not even see. At the DIFF-side join a missing subtree never arrives, because `git diff`
# must read the subtree of any directory the range touches and fails first (the UNRESOLVABLE
# refusal above). What does arrive is a directory whose `.dist-only` BLOB is missing — the tree
# resolves, so `ls-tree` names the entry, `cat-file -e` answers 1, and the probe answers 125.
#
# The world is asserted to DISCRIMINATE before any verdict is read: the old spelling and the new
# one must disagree on the subject and agree on a readable control directory.
build_p21_world
if [ "$P21_DISC" != "$P21_DISC_WANT" ]; then
  bad "FIXTURE BROKEN: Part 21's world does not discriminate ($P21_DISC, want tree:rp=1,ce=1 blob:rp=0,ce=1 ctl:rp=0,ce=0) — the moved objects did not leave the states the two spellings disagree on, so no verdict below would mean anything"
else
  ok "Part 21 world discriminates: a missing subtree reads rev-parse 1 (the old 'absent') and a missing marker blob reads rev-parse 0 while cat-file fails, against a readable control"
  p21_g="$(p21_over "$RUNNER")"
  if [ "$p21_g" = "rc=2 why=unconfirmed keeper=kept" ]; then
    ok "Part 21a: a named directory whose tree at theirs cannot be read is REFUSED as unconfirmed, not reported as a driver upstream deleted, and the readable directory beside it is accepted"
  else
    bad "Part 21a: an unreadable named tree read '$p21_g', want 'rc=2 why=unconfirmed keeper=kept'. The .dist-only probe is answering an unreadable subtree as an absent marker"
  fi
  p21_g="$(p21_diff "$RUNNER")"
  if [ "$p21_g" = "rc=2 tag=unconfirmed subject=blobless" ]; then
    ok "Part 21b: a diff-touched directory whose .dist-only blob cannot be read is REFUSED under its own COVERAGE: UNCONFIRMED tag, never skipped or counted"
  else
    bad "Part 21b: a diff-touched directory with an unreadable marker read '$p21_g', want 'rc=2 tag=unconfirmed subject=blobless'"
  fi
fi

# --- Part 22: A STAGING WRITE THAT FAILS IS A REFUSAL (BL-360) --------------------------------
# Every loop in the runner reads a file `su_stage` wrote, and a failed write must end the run with
# exit 2 — the heredocs it replaced ran their loops ZERO times and read the empty input as clean.
# FORCED, NEVER SAMPLED: a `mktemp` stub on PATH hands the runner a READ-ONLY staging directory,
# so the first staging write fails with EACCES. It claims only the runner's own `su-stage.XXXXXX`
# call (lib.sh's memo `mktemp` passes through) and logs each claim, and the arm asserts it fired.
# EACCES stands in for the EFBIG/ENOSPC a real full TMPDIR gives; the subject is that the write's
# STATUS is read, which is the same branch for every errno.
p22_stub "$P21/stub"
p22_g="$(p22 "$RUNNER" yes)"
if [ "$p22_g" = "rc=2 staging=refused fired=1" ]; then
  ok "Part 22: a staging directory the runner cannot write is REFUSED at the first staged input, exit 2, with the stub shown to fire"
else
  bad "Part 22: an unwritable staging directory read '$p22_g', want 'rc=2 staging=refused fired=1'"
fi
p22_g="$(p22 "$RUNNER" no)"
if [ "$p22_g" = "rc=0 staging=none fired=0" ]; then
  ok "Part 22 healthy twin: the same world unstubbed runs green, so the refusal above is the staging write and not a runner that refuses everything"
else
  bad "Part 22 healthy twin read '$p22_g', want 'rc=0 staging=none fired=0'"
fi
rm -rf "$P21" "$P21C"

# --- Part Q: A NON-ASCII FIXTURE DIRECTORY IS JOINED BY ITS RAW NAME (BL-364) -------------------
# Under git's default `core.quotePath` the diff lists `"core/fixtures/caf\303\251/run.sh"`, and the
# directory extraction is anchored on `^core/fixtures/`, so the quoted line was DROPPED from the
# diff-touched set: a slice omitting a fixture the pull changes passed the coverage join — the
# acquitting direction. Its own distribution, so no other part's diff census moves. Three runs:
#   Q1  the slice omits `café`                     -> refused, `café` named, the plain offender too
#   Q2  the slice names `café` as a bare name       -> green, both fixtures run
#   Q3  the slice names it as `core/fixtures/café/` -> the SAME run as Q2 (the path form's name
#       predicate was an ASCII class, which refused the raw name as unparsable)
# Both locales for Q1, because the cell is a claim about bytes.
build_q_world
q_consumer
# SEED CONTROL: the range really lists the accented directory, raw, and quoted under the default.
q_raw="$(QDG -c core.quotePath=false diff --name-only "$QD_B" "$QD_T" -- core/fixtures/ 2>/dev/null | grep -cF "core/fixtures/$QU/")" || q_raw=0
q_quo="$(QDG -c core.quotePath=true diff --name-only "$QD_B" "$QD_T" -- core/fixtures/ 2>/dev/null | grep -c '^"core/fixtures/caf')" || q_quo=0
if [ "$q_raw" = 1 ] && [ "$q_quo" = 1 ]; then
  ok "SEED: the non-ASCII range lists core/fixtures/$QU raw under core.quotePath=false and C-quoted under the default"
else
  bad "FIXTURE ERROR: the non-ASCII range does not discriminate (raw=$q_raw quoted=$q_quo); Part Q would assert over a diff that cannot lose the row"
fi
Q_GREEN="rc=0 cov= sec=green-one,plain-touched,$QU,"
for qloc in utf8 c; do
  got="$(q_run "$RUNNER" "$qloc" green-one plain-touched)"
  if [ "$got" = "rc=2 cov=$QU, sec=" ]; then
    ok "Part Q1 ($qloc): a slice omitting the diff-touched fixture $QU is refused with it named"
  else
    bad "Part Q1 ($qloc): got [$got], want [rc=2 cov=$QU, sec=]. A C-quoted diff line drops the accented directory from the diff-touched set and the incomplete slice runs"
  fi
done
got="$(q_run "$RUNNER" utf8 green-one plain-touched "$QU")"
if [ "$got" = "$Q_GREEN" ]; then
  ok "Part Q2: naming $QU as a bare name clears the join and runs all three"
else
  bad "Part Q2: got [$got], want [$Q_GREEN]. The bare raw name must satisfy the join that names it"
fi
# Q3 RUNS IN BOTH LOCALES AND ONLY THE C ONE DISCRIMINATES. Measured: bash's `[!A-Za-z0-9._-]`
# ACCEPTS the accented name under en_US.UTF-8 (the range is collation-ordered there) and refuses
# it under LC_ALL=C — so a UTF-8-only cell passes the ASCII class and proves nothing.
for qloc in utf8 c; do
  got="$(q_run "$RUNNER" "$qloc" green-one plain-touched "core/fixtures/$QU/")"
  if [ "$got" = "$Q_GREEN" ]; then
    ok "Part Q3 ($qloc): the path form core/fixtures/$QU/ is normalised to the raw name and is the same run as Q2"
  else
    bad "Part Q3 ($qloc): got [$got], want [$Q_GREEN]. An ASCII-only name predicate refuses the raw accented name as an unparsable argument"
  fi
done
# Part Q4: `core/fixtures/..` is not a name. It carries no slash after the prefix is stripped, so
# without the explicit `.|..` arm it was normalised to `..` and convicted as a DELETED DRIVER — a
# row sending the operator after an upstream deletion that never happened.
ERRQ4="$CONS2/err-partq4.txt"; rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$RUNNER" "$QD" "$QD_B" "$QD_T" "$CONS2" green-one plain-touched "$QU" "core/fixtures/.." >/dev/null 2>"$ERRQ4"
rcq4=$?
if [ "$rcq4" -eq 2 ] && grep -qF '  core/fixtures/.. — not a fixture NAME' "$ERRQ4" && ! grep -qF 'no run.sh at' "$ERRQ4"; then
  ok "Part Q4: core/fixtures/.. is refused as not a fixture NAME, never as a deleted driver"
else
  bad "Part Q4: core/fixtures/.. was not refused as a non-name (rc=$rcq4, stderr: $(grep -F 'core/fixtures/..' "$ERRQ4" 2>/dev/null | head -1))"
fi
rm -rf "$CONS2/tests/fixtures/plain-touched" "$CONS2/tests/fixtures/$QU" "$QD"

echo
if [ "$fails" -eq 0 ]; then
  echo "self-update-fixture-log: PASS"
  exit 0
fi
echo "self-update-fixture-log: FAIL ($fails)"
exit 1
