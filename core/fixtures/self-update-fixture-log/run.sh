#!/usr/bin/env bash
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
# Usage: run.sh [path-to-self-update-fixtures.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = the harness could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
RUNNER="$(pick "${1:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/self-update-fixtures.sh" \
                        "$HERE/../../skills/ai-dlc-update/reconcile/self-update-fixtures.sh" \
                        "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/self-update-fixtures.sh")"
[ -n "$RUNNER" ] || { echo "FIXTURE ERROR: cannot locate self-update-fixtures.sh" >&2; exit 2; }
RECONCILE="$(cd "$(dirname "$RUNNER")" && pwd)"

CONS="$(bash "$HERE/seed.sh")"
CONS2="$(bash "$HERE/seed.sh")"
DIST="$(mktemp -d)"
WREPO="$(mktemp -d)"
trap 'rm -rf "$CONS" "$CONS2" "$DIST" "$WREPO"' EXIT
LOGDIR="$CONS/_bmad-output/ai-dlc-update"
LOGDIR2="$CONS2/_bmad-output/ai-dlc-update"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

newest_log()  { ls -t "$LOGDIR"/self-update-fixtures-*.md 2>/dev/null | head -1; }
newest_log2() { ls -t "$LOGDIR2"/self-update-fixtures-*.md 2>/dev/null | head -1; }

# The refusal list, read back as a SET rather than as N greps. An equality against the whole
# list is what carries the exemptions: a `.dist-only` directory that stopped being exempt
# appears here, and no absence-shaped assertion has to be written for it separately.
cov_set() {
  { [ -n "${1:-}" ] && [ -f "$1" ]; } || return 0
  sed -n '/^COVERAGE: the diff changes/,/^$/p' "$1" \
    | sed -n 's/^  \([A-Za-z0-9._-][A-Za-z0-9._-]*\)$/\1/p' | sort | tr '\n' ','
}

# --- The throwaway DISTRIBUTION repo ------------------------------------------------------
# `--no-verify` and an empty `init.templateDir` because this runs on an operator's machine:
# a global hook path or commit template would otherwise decide whether the seed builds.
G()    { git -C "$DIST" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid \
                        -c commit.gpgsign=false "$@"; }
dput() { mkdir -p "$(dirname "$DIST/$1")" && printf '%s\n' "$2" > "$DIST/$1"; }

git -c init.templateDir= init -q -b main "$DIST" >/dev/null 2>&1 \
  || git -c init.templateDir= init -q "$DIST" >/dev/null 2>&1

for f in touched-shippable touched-named touched-distonly touched-deleted untouched-one; do
  dput "core/fixtures/$f/run.sh" 'at base'
done
dput "core/fixtures/touched-distonly/.dist-only" 'a mutation battery over core sources; never shipped'
dput "core/scripts/machinery.sh" 'at base'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m base >/dev/null 2>&1
D_BASE="$(G rev-parse HEAD 2>/dev/null)"

# theirs: three fixtures changed, one deleted, one left alone, and a machinery path moved
# alongside them so the `-- core/fixtures/` pathspec has something to exclude.
for f in touched-shippable touched-named touched-distonly; do
  dput "core/fixtures/$f/run.sh" 'at theirs'
done
rm -rf "$DIST/core/fixtures/touched-deleted"
dput "core/scripts/machinery.sh" 'at theirs'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m theirs >/dev/null 2>&1
D_THEIRS="$(G rev-parse HEAD 2>/dev/null)"
G tag theirs-tag >/dev/null 2>&1

# A quiet commit on top: machinery only, no fixture touched. Parts 1-6 run over this range so
# the coverage join stands down and they assert about the LOG, exactly as they did before.
dput "core/scripts/machinery.sh" 'after theirs'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m quiet >/dev/null 2>&1
D_QUIET="$(G rev-parse HEAD 2>/dev/null)"
D_TREE="$(G rev-parse "${D_THEIRS}^{tree}" 2>/dev/null)"

# A range carrying ONE diff-touched fixture and no exempt directory at all. Part 8 runs over
# this rather than over base..theirs so that a mutant which breaks an EXEMPTION cannot also
# fail Part 8: the exemptions are Part 7's to own, and two arms failing on one mutation means
# one of them is asserting the other's subject.
dput "core/fixtures/touched-shippable/run.sh" 'after quiet'
G add -A >/dev/null 2>&1; G commit -q --no-verify -m ship >/dev/null 2>&1
D_SHIP="$(G rev-parse HEAD 2>/dev/null)"

# --- A repo that is a git checkout but NOT the distribution --------------------------------
# The state is reachable from THIS fixture's own resolver: `pick` above takes the runner from
# three layouts, two of them consumer layouts, and walking up four levels from a consumer
# `.claude/skills/.../reconcile` lands on the consumer root — a git repo whose `theirs` has no
# `core/fixtures` tree, so the diff comes back empty and the join passes having seen nothing.
#
# THE SEED IS SHAPED TO SAY WHICH READ IS WRONG, not merely that something is. `core/fixtures`
# is COMMITTED AT BASE and deleted at theirs, and then written back to the WORKTREE
# uncommitted — so a guard keyed on the base ref, or on what is on disk, would pass here and
# only a read at THEIRS refuses. That is also why the exemptions have to be committed at the
# theirs commit rather than left on disk in the distribution seed above.
W()     { git -C "$WREPO" -c user.name=ai-dlc-fixture -c user.email=fixture@invalid \
                          -c commit.gpgsign=false "$@"; }
wput()  { mkdir -p "$(dirname "$WREPO/$1")" && printf '%s\n' "$2" > "$WREPO/$1"; }

git -c init.templateDir= init -q -b main "$WREPO" >/dev/null 2>&1 \
  || git -c init.templateDir= init -q "$WREPO" >/dev/null 2>&1
wput "core/fixtures/touched-shippable/run.sh" 'present at base only'
wput "tests/fixtures/green-one/run.sh" 'a consumer-layout fixture'
W add -A >/dev/null 2>&1; W commit -q --no-verify -m base >/dev/null 2>&1
W_BASE="$(W rev-parse HEAD 2>/dev/null)"

rm -rf "$WREPO/core"
wput "tests/fixtures/green-one/run.sh" 'a consumer-layout fixture, changed'
W add -A >/dev/null 2>&1; W commit -q --no-verify -m theirs >/dev/null 2>&1
W_THEIRS="$(W rev-parse HEAD 2>/dev/null)"
wput "core/fixtures/touched-shippable/run.sh" 'back on disk, committed nowhere'

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

# --- MUTATION: prove the arms above can fail -----------------------------------------------
# The runner sources nothing from its own directory, so a lone copy is a working harness here
# — but the copies are still taken beside the original and checked with an unmutated control,
# because "the mutant emitted nothing" and "the mutant survived" are the same bytes.
MUTDIR="$(mktemp -d)"; trap 'rm -rf "$CONS" "$CONS2" "$DIST" "$MUTDIR"' EXIT
cp "$RECONCILE"/*.sh "$MUTDIR"/ 2>/dev/null
CTL="$MUTDIR/control-unmutated.sh"; cp "$RUNNER" "$CTL"

# Every mutation is a copy, and the anchor must occur EXACTLY once. A `replace(...,1)` against
# an anchor that has moved edits nothing and comes back green, and one against an anchor that
# has become ambiguous edits the wrong site — both are mutants that prove nothing, and both
# read as a passing battery.
mkmutant() { # $1=dest $2=old $3=new
  MUT_OLD="$2" MUT_NEW="$3" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
old, new = os.environ["MUT_OLD"], os.environ["MUT_NEW"]
if s.count(old) != 1: sys.exit(3)
open(sys.argv[2], "w").write(s.replace(old, new, 1))' "$RUNNER" "$1" 2>/dev/null || return 1
  [ -s "$1" ] && ! cmp -s "$RUNNER" "$1"
}

# --- CONTROL --------------------------------------------------------------------------------
# Two arms, and the second one is why the first is not enough: an rc=2-and-nothing-reported
# control passes against a subject replaced by `exit 0`, because that is exactly what a clean
# copy looks like. The green arm demands a baseline row be THERE.
bash "$CTL" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" >/dev/null 2>&1
if [ $? -eq 2 ]; then
  ok "CONTROL: the unmutated copy still exits 2 on an empty set — the mutant verdicts below are their edits"
else
  bad "FIXTURE ERROR: the unmutated copy did not exit 2 on an empty set, so the copied harness is what is being measured"
fi
rm -f "$LOGDIR2"/self-update-fixtures-*.md
bash "$CTL" "$DIST" "$D_QUIET" "$D_SHIP" "$CONS2" touched-shippable green-one >/dev/null 2>&1
rc=$?
LC="$(newest_log2)"
if [ "$rc" -eq 0 ] && [ -n "$LC" ] && grep -qF "===== FIXTURE green-one =====" "$LC"; then
  ok "CONTROL: the unmutated copy runs the named fixtures and writes their sections — a copy that emitted nothing would fail here rather than score as a kill"
else
  bad "FIXTURE ERROR: the unmutated copy did not produce a green run with a green-one section (rc=$rc). Every kill below would be the copied harness dying, not the mutation"
fi

# --- MUTANT 0: the empty-set guard returns 0 ------------------------------------------------
M0="$MUTDIR/m0-emptyset-green.sh"
if mkmutant "$M0" '  exit 2
fi

SELF=' '  exit 0
fi

SELF='; then
  bash "$M0" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ok "MUTATION — with the empty-set guard returning 0, naming nothing reads as a green suite: Part 4 is what catches that"
  else
    bad "MUTATION — the empty-set guard was neutered and the runner still refused; Part 4's assertion is vacuous"
  fi
else
  bad "FIXTURE ERROR: the empty-set anchor no longer occurs exactly once in the runner — Part 4 proves nothing. Re-anchor it on the runner's real empty-set guard"
fi

# --- MUTANT 1: the .dist-only exemption inverted ---------------------------------------------
M1="$MUTDIR/m1-exemption-inverted.sh"
if mkmutant "$M1" 'core/fixtures/${d}/.dist-only" 2>/dev/null && continue' \
                  'core/fixtures/${d}/.dist-only" 2>/dev/null || true'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M1" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >/dev/null 2>&1
  if [ "$(cov_set "$(newest_log2)")" = "touched-distonly,touched-shippable," ]; then
    ok "MUTATION — with the .dist-only exemption inverted a never-shipped fixture joins the refusal: Part 7's set equality is what catches that"
  else
    bad "MUTATION — the .dist-only exemption was inverted and the refusal list did not change. Part 7 asserts an exemption no run can move, so the exemption is untested"
  fi
else
  bad "FIXTURE ERROR: the .dist-only exemption anchor no longer occurs exactly once in the runner — the exemption half of Part 7 proves nothing"
fi

# --- MUTANT 2: the coverage join deleted outright --------------------------------------------
# The block is excised rather than edited, because a partial revert leaves a mutant that proves
# whichever layer was left in place.
M2="$MUTDIR/m2-coverage-deleted.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The COVERAGE join"), s.index("n_run=0; n_ok=0")
open(sys.argv[2], "w").write(s[:a] + s[b:])' "$RUNNER" "$M2" 2>/dev/null
if [ -s "$M2" ] && ! cmp -s "$RUNNER" "$M2"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M2" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && ! grep -qF "COVERAGE:" "$LM"; then
    ok "MUTATION — with the whole coverage join removed the incomplete slice runs green: Part 7 is what catches that"
  else
    bad "MUTATION — the coverage join was removed and the incomplete slice was still refused (rc=$rc). Something else is producing Part 7's verdict"
  fi
else
  bad "FIXTURE ERROR: the coverage block could not be excised — its start or end anchor has moved, and Part 7 proves nothing"
fi

# --- MUTANT 3: the coverage join moved AFTER the fixture loop ---------------------------------
# A placement mutant, and the reason Part 7 asserts on ordering rather than on the verdict: this
# copy still refuses, with the same list, having already run and reported every fixture first.
M3="$MUTDIR/m3-coverage-after-loop.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The COVERAGE join"), s.index("n_run=0; n_ok=0")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("{\n  echo \"# summary:")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M3" 2>/dev/null
if [ -s "$M3" ] && ! cmp -s "$RUNNER" "$M3" && ! cmp -s "$M2" "$M3"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M3" "$DIST" "$D_BASE" theirs-tag "$CONS2" touched-named green-one >"$CONS2/out-m3.txt" 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ -n "$LM" ] && grep -qF "COVERAGE: the diff changes" "$LM" \
     && grep -qF "===== FIXTURE green-one =====" "$LM"; then
    ok "MUTATION — moved below the loop the join still refuses with the same list, having reported every fixture first: only Part 7's ordering arm sees it"
  else
    bad "MUTATION — the join was moved after the fixture loop and Part 7's ordering arm did not fire (rc=$rc). An arm that cannot tell before from after is asserting the verdict twice"
  fi
else
  bad "FIXTURE ERROR: the coverage block could not be relocated — an anchor has moved, or the relocated copy is byte-identical to the deleted one, and the ordering arm proves nothing"
fi

# --- MUTANT 4: the ref-resolution loop neutered ------------------------------------------------
# `&& continue` becomes `; continue`, so every ref is accepted. On a BOGUS ref this changes
# almost nothing — the diff-failure arm underneath still exits 2 — which is why the mutant is
# scored on Part 12's input instead: `git diff <tree> <commit>` succeeds, so the copy runs the
# join against a base that names no commit and reports a green suite.
M4="$MUTDIR/m4-refcheck-neutered.sh"
if mkmutant "$M4" 'rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1 && continue' \
                  'rev-parse --verify --quiet "${r}^{commit}" >/dev/null 2>&1; continue'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M4" "$DIST" "$D_TREE" theirs-tag "$CONS2" green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && ! grep -qF "COVERAGE: UNRESOLVABLE" "$LM"; then
    ok "MUTATION — with the ref peel removed a base that names a TREE reports a green suite: Part 12 is what catches that"
  else
    bad "MUTATION — the ref-resolution loop was neutered and the run still refused (rc=$rc). Part 12's input does not reach that loop, so the peel to ^{commit} is untested"
  fi
else
  bad "FIXTURE ERROR: the ref-resolution anchor no longer occurs exactly once in the runner — Parts 10 to 12 prove nothing"
fi

# --- MUTANT 5: the distribution check neutered ------------------------------------------------
# `if ! git cat-file -e ...` becomes `if false`, so any git repo is accepted. Part 13 is
# absence-shaped without this: the arm asks for a refusal, and a subject that refuses nothing
# at all — including one replaced by `exit 0` — is exactly what a wrong repo looks like once
# the guard is gone. The copy reports a GREEN SUITE over a checkout holding no fixtures.
M5="$MUTDIR/m5-distcheck-neutered.sh"
if mkmutant "$M5" 'if ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures" 2>/dev/null; then' \
                  'if false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M5" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE green-one =====" "$LM" \
     && ! grep -qF "COVERAGE:" "$LM"; then
    ok "MUTATION — with the distribution check removed a repo holding no core/fixtures runs to a green suite: Part 13 is what catches that"
  else
    bad "MUTATION — the distribution check was neutered and the wrong repo was still refused (rc=$rc). Part 13's verdict is coming from somewhere else, and the guard is untested"
  fi
else
  bad "FIXTURE ERROR: the distribution-check anchor no longer occurs exactly once in the runner — Part 13 proves nothing"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "self-update-fixture-log: PASS"
  exit 0
fi
echo "self-update-fixture-log: FAIL ($fails)"
exit 1
