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

# The OVER-completeness refusal list, read the same way and for the same reason. Its rows carry
# a reason after the directory name, so the name is taken up to the first space; the em dash is
# deliberately not in the pattern, because a multibyte character in a bracket class is three
# separate bytes to a BSD `sed` and the match would depend on the locale the suite happens to
# run under. Set equality here is what carries the ACQUITTALS: a legitimate directory that
# started being refused shows up as an extra member, with no absence-shaped assertion written
# for it separately.
uns_set() {
  { [ -n "${1:-}" ] && [ -f "$1" ]; } || return 0
  sed -n '/^COVERAGE: the named set contains/,/^$/p' "$1" \
    | sed -n 's/^  \([A-Za-z0-9._-][A-Za-z0-9._-]*\) .*$/\1/p' | sort | tr '\n' ','
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

# EVERY NAMED DIRECTORY IS READ IN THIS REPO, so every name any part below passes to the
# runner has to exist here. The OVER-completeness arm probes `${THEIRS}:core/fixtures/<d>/...`
# for each argument, so a consumer-side-only name — `green-one`, `red-one`, `cwd-probe`, the
# deliberately-absent `never-written-by-the-slice` — resolves to nothing and is convicted as
# unshippable before the run reaches whatever the part was actually asserting. That is not a
# subject defect: a real step-2 set names directories that exist in `core/fixtures/`.
for f in green-one cwd-probe red-one never-written-by-the-slice \
         disk-only-distonly disk-missing-driver; do
  dput "core/fixtures/$f/run.sh" 'at base'
done

# The OVER-completeness cases, all UNTOUCHED by base..theirs so that naming one exercises the
# over-arm alone and Part 0's diff-side census is unmoved:
#   named-distonly       carries the marker at theirs — the filed episode's shape
#   theirs-only-distonly the marker at theirs and NOT on disk
#   theirs-only-nodriver no run.sh at theirs, and one written to disk below
#   disk-only-distonly   shippable at theirs, with a marker written to disk below
#   disk-missing-driver  shippable at theirs, with its run.sh removed from disk below
dput "core/fixtures/named-distonly/run.sh" 'at base'
dput "core/fixtures/named-distonly/.dist-only" 'a mutation battery over core sources; never shipped'
dput "core/fixtures/theirs-only-distonly/run.sh" 'at base'
dput "core/fixtures/theirs-only-distonly/.dist-only" 'a mutation battery over core sources; never shipped'
dput "core/fixtures/theirs-only-nodriver/.keep" 'a directory upstream carries with no driver in it'

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

# --- The DIST WORKTREE, made to DISAGREE with `theirs` in both directions -------------------
# LAST, and uncommitted, because nothing below runs `G add`. Every probe in the runner reads at
# a REF; an implementation reading `$DIST/core/fixtures/<d>/...` off disk answers for whatever
# the checkout happens to hold, which is a different tree from the one being delivered. On a
# seed where disk and theirs AGREE the two implementations are indistinguishable, so the wrong
# one passes. These four writes split them for BOTH probes in BOTH directions, and they are
# confined to four directories no other part names — the disk-reading mutant must fail Part 17
# and nothing else, or the arm that owns the read is not identifiable.
rm -f "$DIST/core/fixtures/theirs-only-distonly/.dist-only"
mkdir -p "$DIST/core/fixtures/theirs-only-nodriver"
printf '%s\n' 'on disk, committed nowhere' > "$DIST/core/fixtures/theirs-only-nodriver/run.sh"
printf '%s\n' 'on disk, committed nowhere' > "$DIST/core/fixtures/disk-only-distonly/.dist-only"
rm -f "$DIST/core/fixtures/disk-missing-driver/run.sh"

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

# --- MUTATION: prove the arms above can fail -----------------------------------------------
# The runner sources nothing from its own directory, so a lone copy is a working harness here
# — but the copies are still taken beside the original and checked with an unmutated control,
# because "the mutant emitted nothing" and "the mutant survived" are the same bytes.
MUTDIR="$(mktemp -d)"; trap 'rm -rf "$CONS" "$CONS2" "$DIST" "$WREPO" "$MUTDIR"' EXIT
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

# A TWO-LAYER revert, for a state two guards independently refuse. A partial revert leaves a
# mutant that proves whichever layer was left in place, and it comes out green — so where a
# second guard covers the first, both come off in one copy and the arm scores the pair. The
# second anchor is counted AFTER the first substitution, so an edit that makes it ambiguous is
# a refusal rather than a silent wrong-site replacement.
mkmutant2() { # $1=dest $2=old1 $3=new1 $4=old2 $5=new2
  MUT_O1="$2" MUT_N1="$3" MUT_O2="$4" MUT_N2="$5" python3 -c 'import os,sys
s = open(sys.argv[1]).read()
for o, n in ((os.environ["MUT_O1"], os.environ["MUT_N1"]),
             (os.environ["MUT_O2"], os.environ["MUT_N2"])):
    if s.count(o) != 1: sys.exit(3)
    s = s.replace(o, n, 1)
open(sys.argv[2], "w").write(s)' "$RUNNER" "$1" 2>/dev/null || return 1
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
#
# TWO LAYERS COME OFF, because a second guard now covers this one. The over-completeness arm
# below also refuses a wrong repo — every `cat-file -e` at a theirs with no `core/fixtures`
# tree fails, so it convicts the whole named set — and with the distribution check alone
# removed this copy would still exit 2, scoring a kill for a guard that had not been reached.
# Removing only the emission keeps the arm's own logic intact and reverts exactly the covering
# layer. Which of the two SHOULD answer is Part 19's subject, not this one's.
M5="$MUTDIR/m5-distcheck-neutered.sh"
if mkmutant2 "$M5" 'if ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures" 2>/dev/null; then' \
                   'if false; then' \
                   'if [ -n "$unshippable" ]; then' \
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

# --- MUTANTS 6 to 13: the OVER-completeness arm --------------------------------------------
# Keyed on LOCATION and on observable BEHAVIOUR, never on a spelling — Mutant 13 is a competent
# author's OTHER phrasing of the same fix and every arm above has to pass it. Each mutant's
# scoring input is the input of the ONE part that owns it, so a mutant that moves two cells is
# a report that two arms are watching the same subject.

# --- MUTANT 6: the whole over-completeness arm excised ---------------------------------------
# Excised rather than edited: a partial revert leaves a mutant that proves whichever probe was
# left in place. The named set is Part 14's, and the surplus directory has a driver in the
# consumer seed — so the copy runs it and reports a GREEN suite, which is exactly what the
# reference consumer saw while the orphan was being committed.
M6="$MUTDIR/m6-overarm-deleted.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
open(sys.argv[2], "w").write(s[:a] + s[b:])' "$RUNNER" "$M6" 2>/dev/null
if [ -s "$M6" ] && ! cmp -s "$RUNNER" "$M6"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M6" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE named-distonly =====" "$LM" \
     && ! grep -qF "COVERAGE: the named set contains" "$LM"; then
    ok "MUTATION — with the over-completeness arm removed, a set naming a never-shipped fixture RUNS it and reports green: Part 14 is what catches that"
  else
    bad "MUTATION — the over-completeness arm was removed and the surplus directory was still refused (rc=$rc). Something else is producing Part 14's verdict, and the arm is untested"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be excised — its start or end anchor has moved, and Parts 14 to 19 prove nothing"
fi

# --- MUTANT 7: the .dist-only probe neutered, the run.sh probe kept ---------------------------
# One exclusion at a time, because a mutant that removes both cannot say which arm saw it. The
# anchor carries the `  if ` prefix that the diff-side copy of the same probe does not, so the
# substitution cannot land on the miss-join's exemption instead.
M7="$MUTDIR/m7-distonly-probe-gone.sh"
if mkmutant "$M7" '  if git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${d}/.dist-only" 2>/dev/null; then' \
                  '  if false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M7" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE named-distonly =====" "$LM"; then
    ok "MUTATION — with only the .dist-only probe gone the never-shipped directory has a run.sh at theirs, passes the surviving probe and is RUN: Part 14 is what catches that"
  else
    bad "MUTATION — the .dist-only probe was removed and the directory was still refused (rc=$rc). Part 14's verdict is coming from the run.sh probe, so the exclusion that produced the filed episode is untested"
  fi
else
  bad "FIXTURE ERROR: the .dist-only probe anchor no longer occurs exactly once in the runner — Part 14 proves nothing"
fi

# --- MUTANT 8: the run.sh probe neutered, the .dist-only probe kept ---------------------------
M8="$MUTDIR/m8-runsh-probe-gone.sh"
if mkmutant "$M8" '  elif ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${d}/run.sh" 2>/dev/null; then' \
                  '  elif false; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M8" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       touched-deleted green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE touched-deleted =====" "$LM"; then
    ok "MUTATION — with only the run.sh probe gone a directory upstream DELETED is accepted and run: Part 15 is what catches that"
  else
    bad "MUTATION — the run.sh probe was removed and the deleted-driver directory was still refused (rc=$rc). Part 15 is being answered by the .dist-only probe, so the second exclusion is untested"
  fi
else
  bad "FIXTURE ERROR: the run.sh probe anchor no longer occurs exactly once in the runner — Part 15 proves nothing"
fi

# --- MUTANT 9: the arm relocated ABOVE the ref-resolution loop --------------------------------
# The placement mutant Part 18 owns. It is a strictly wider move than Mutant 10's — above the
# resolution loop is also above the wrong-repo guard — so Part 19 fires on this copy too. That
# is the direction that is allowed: Mutant 10 is the input only Part 19 can see, and it is what
# stops Part 19 from being an echo of Part 18.
M9="$MUTDIR/m9-overarm-above-refloop.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("for r in \"$BASE\" \"$THEIRS\"; do")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M9" 2>/dev/null
if [ -s "$M9" ] && ! cmp -s "$RUNNER" "$M9" && ! cmp -s "$M6" "$M9"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M9" "$DIST" "$D_THEIRS" no-such-theirs-ref "$CONS2" green-one touched-shippable \
    >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$LM")" = "green-one,touched-shippable," ] \
     && ! grep -qF "COVERAGE: UNRESOLVABLE" "$LM"; then
    ok "MUTATION — sited above the ref-resolution loop the arm probes an unresolvable theirs, every cat-file fails, and it convicts two directories the distribution ships: Part 18 is what catches that"
  else
    bad "MUTATION — the arm was moved above the ref-resolution loop and Part 18's arm did not fire (rc=$rc, refused '$(uns_set "$LM")'). An arm keyed on the exit code alone cannot tell the resolution refusal from this one, because both are 2"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be relocated above the ref loop — an anchor has moved, or the relocated copy is byte-identical to the deleted one, and Part 18 proves nothing"
fi

# --- MUTANT 10: the arm relocated ABOVE the wrong-repo guard, BELOW the ref loop ---------------
# The input only Part 19 can see. Both refs resolve here, so the resolution loop is satisfied and
# Part 18 passes against this copy — what it gets wrong is a checkout whose theirs carries no
# `core/fixtures` tree at all, where every probe fails again and the repo's defect is reported as
# the slice's.
M10="$MUTDIR/m10-overarm-above-distguard.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("# --- The OVER-completeness arm"), s.index("# The diff is taken into a variable")
blk, t = s[a:b], s[:a] + s[b:]
c = t.index("# AND `$DIST` MUST BE THE DISTRIBUTION")
open(sys.argv[2], "w").write(t[:c] + blk + t[c:])' "$RUNNER" "$M10" 2>/dev/null
if [ -s "$M10" ] && ! cmp -s "$RUNNER" "$M10" && ! cmp -s "$M9" "$M10"; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M10" "$WREPO" "$W_BASE" "$W_THEIRS" "$CONS2" green-one touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$LM")" = "green-one,touched-shippable," ] \
     && ! grep -qF "COVERAGE: WRONG-REPO" "$LM"; then
    ok "MUTATION — sited above the wrong-repo guard the arm indicts the named set of a checkout that is simply the wrong repo, and Part 18 cannot see it because both refs resolve: Part 19 is what catches that"
  else
    bad "MUTATION — the arm was moved above the wrong-repo guard and Part 19's arm did not fire (rc=$rc, refused '$(uns_set "$LM")'). Part 19 is then an echo of Part 18 and the ordering it asserts is untested"
  fi
else
  bad "FIXTURE ERROR: the over-completeness block could not be relocated above the wrong-repo guard — an anchor has moved, or the copy is byte-identical to Mutant 9's, and Part 19 proves nothing"
fi

# --- MUTANT 11: both probes read the DISTRIBUTION CHECKOUT instead of theirs -------------------
# The implementation a naive seed cannot distinguish from the right one. It returns the exact
# INVERSE of Part 17's set, and it is wrong in both directions at once: it acquits an orphan
# bound for the consumer and convicts two fixtures the pull genuinely delivers.
M11="$MUTDIR/m11-probes-read-disk.sh"
if mkmutant2 "$M11" 'if git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${d}/.dist-only" 2>/dev/null; then' \
                    'if [ -f "$DIST/core/fixtures/${d}/.dist-only" ]; then' \
                    'elif ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${d}/run.sh" 2>/dev/null; then' \
                    'elif [ ! -f "$DIST/core/fixtures/${d}/run.sh" ]; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M11" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       theirs-only-distonly theirs-only-nodriver disk-only-distonly disk-missing-driver green-one \
       >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "disk-missing-driver,disk-only-distonly," ]; then
    ok "MUTATION — probing the checkout instead of theirs inverts the verdict exactly: the two orphans are acquitted and two shippable fixtures convicted. Part 17 is what catches that"
  else
    bad "MUTATION — the probes were pointed at the \$DIST worktree and Part 17 did not change its answer (rc=$rc, refused '$(uns_set "$(newest_log2)")'). Then disk and theirs agree for every directory Part 17 names, and the arm cannot tell the two implementations apart"
  fi
else
  bad "FIXTURE ERROR: one of the two probe anchors no longer occurs exactly once in the runner — Part 17 proves nothing"
fi

# --- MUTANT 12: the refusal degraded to a warning that falls through ---------------------------
# `exit 2` becomes `:`. The two refusal blocks in this runner end in BYTE-IDENTICAL three-line
# tails, so the anchor carries the remedy sentence that only this one has — keying on the shared
# tail would edit the miss-join and score a kill this arm did not earn.
M12="$MUTDIR/m12-refusal-is-a-warning.sh"
if mkmutant "$M12" '  never ships — the RETIRED-FIXTURE-ORPHAN class. Drop them from the slice and re-run." >&2
  echo "  log: $LOG" >&2
  exit 2' \
                   '  never ships — the RETIRED-FIXTURE-ORPHAN class. Drop them from the slice and re-run." >&2
  echo "  log: $LOG" >&2
  :'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M12" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  if [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "COVERAGE: the named set contains" "$LM" \
     && grep -qF "===== FIXTURE named-distonly =====" "$LM"; then
    ok "MUTATION — reporting the surplus directory and then RUNNING it anyway exits 0, and a green exit is the only thing step 2 reads: Part 14's exit-code and ordering arms are what catch that"
  else
    bad "MUTATION — the refusal was degraded to a warning and the run still failed (rc=$rc). Part 14 is asserting on the message alone, and a finding printed above a green exit reaches nobody"
  fi
else
  bad "FIXTURE ERROR: the refusal-tail anchor no longer occurs exactly once in the runner — Part 14's exit-code arm proves nothing"
fi

# --- MUTANT 13: a SECOND SPELLING of the CORRECT fix, which must PASS --------------------------
# A competent author's other phrasing: the two probes lifted into a helper that returns the
# reason, the loop reduced to a call and an append. Same reads, same ref, same messages, same
# exit. A battery that rejects this is not testing the property, it is testing one author's
# formatting — and the next correct change to the runner would come back red for no reason.
SPELL2="$MUTDIR/second-spelling-body.txt"
cat > "$SPELL2" <<'SPELLEOF'
unship_reason() { # $1=directory name — echoes the reason it cannot ship, or nothing
  if git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${1}/.dist-only" 2>/dev/null; then
    printf 'carries .dist-only at %s: never shipped, so no consumer can hold it' "$THEIRS"
  elif ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${1}/run.sh" 2>/dev/null; then
    printf 'no run.sh at %s: upstream deleted the driver, so there is nothing to write' "$THEIRS"
  fi
}
unshippable=""
for d in "$@"; do
  why="$(unship_reason "$d")"
  [ -n "$why" ] || continue
  unshippable="$unshippable
  $d — $why"
done

if [ -n "$unshippable" ]; then
  { echo "COVERAGE: the named set contains fixture(s) no consumer can run:"
    printf '%s\n' "${unshippable#
}"
    echo ""; } >> "$LOG"
  echo "self-update-fixtures: the named set contains fixtures no consumer can run:" >&2
  printf '%s\n' "$unshippable" >&2
  echo "  Step 2 derives the covering set by hand and the exclusions are stated for the" >&2
  echo "  diff-side term. Writing one of these into the consumer creates a fixture core" >&2
  echo "  never ships — the RETIRED-FIXTURE-ORPHAN class. Drop them from the slice and re-run." >&2
  echo "  log: $LOG" >&2
  exit 2
fi

SPELLEOF
M13="$MUTDIR/m13-second-spelling.sh"
python3 -c 'import sys
s = open(sys.argv[1]).read()
a, b = s.index("unshippable=\"\"\n"), s.index("# The diff is taken into a variable")
open(sys.argv[2], "w").write(s[:a] + open(sys.argv[3]).read() + s[b:])' "$RUNNER" "$M13" "$SPELL2" 2>/dev/null
if [ -s "$M13" ] && ! cmp -s "$RUNNER" "$M13"; then
  s13=0
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       named-distonly green-one cwd-probe touched-shippable >/dev/null 2>&1
  [ $? -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "named-distonly," ] || s13=$((s13+1))
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       theirs-only-distonly theirs-only-nodriver disk-only-distonly disk-missing-driver green-one \
       >/dev/null 2>&1
  [ $? -eq 2 ] && [ "$(uns_set "$(newest_log2)")" = "theirs-only-distonly,theirs-only-nodriver," ] || s13=$((s13+1))
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M13" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       green-one cwd-probe touched-named touched-shippable >/dev/null 2>&1
  rc=$?
  LM="$(newest_log2)"
  { [ "$rc" -eq 0 ] && [ -n "$LM" ] && grep -qF "===== FIXTURE touched-named =====" "$LM" \
      && ! grep -qF "COVERAGE: the named set contains" "$LM"; } || s13=$((s13+1))
  if [ "$s13" -eq 0 ]; then
    ok "SECOND SPELLING — the same fix written with a reason-returning helper passes Parts 14, 16 and 17 unchanged: the arms are keyed on the property, not on one author's phrasing"
  else
    bad "SECOND SPELLING — an equivalent implementation of the SAME fix failed $s13 of Parts 14, 16 and 17. A battery that only accepts the phrasing it was written against rejects the next correct change, and this repo has shipped a receipt that certified a regression and refused the real fix"
  fi
else
  bad "FIXTURE ERROR: the second spelling could not be built — the over-completeness block's anchors have moved, and nothing establishes that Parts 14 to 19 accept an equivalent implementation"
fi

# --- MUTANT 14: the .dist-only probe WIDENED to convict every shippable directory -------------
# The mutation the other seven cannot produce. Every one of them makes the arm say LESS, and an
# arm that says less is caught by a set equality missing a member; this one makes it say MORE,
# and Part 16 is the only arm whose subject that is. It was the last arm here with no mutant at
# all, which is the state `fixture-mutants.md` names: an arm asserting that nothing was said
# passes against a subject that says nothing, and only a widening copy tells the two apart.
M14="$MUTDIR/m14-distonly-probe-widened.sh"
if mkmutant "$M14" '  if git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${d}/.dist-only" 2>/dev/null; then' \
                   '  if ! git -C "$DIST" cat-file -e "${THEIRS}:core/fixtures/${d}/.dist-only" 2>/dev/null; then'; then
  rm -f "$LOGDIR2"/self-update-fixtures-*.md
  bash "$M14" "$DIST" "$D_THEIRS" "$D_QUIET" "$CONS2" \
       green-one cwd-probe touched-named touched-shippable >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ] \
     && [ "$(uns_set "$(newest_log2)")" = "cwd-probe,green-one,touched-named,touched-shippable," ]; then
    ok "MUTATION — with the .dist-only probe inverted the arm convicts every directory a consumer CAN run and wedges the self-update: Part 16 is what catches that"
  else
    bad "MUTATION — the .dist-only probe was widened to convict everything and the wholly shippable set was still accepted (rc=$rc, refused '$(uns_set "$(newest_log2)")'). Part 16 asserts an absence no run can produce, so it would pass against a subject that says nothing"
  fi
else
  bad "FIXTURE ERROR: the .dist-only probe anchor no longer occurs exactly once in the runner — Part 16 proves nothing"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "self-update-fixture-log: PASS"
  exit 0
fi
echo "self-update-fixture-log: FAIL ($fails)"
exit 1
