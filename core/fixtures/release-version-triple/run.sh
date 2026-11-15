#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# release-version-triple — assert the commit subject, VERSION and the CHANGELOG's
# top heading are joined, and that a disagreement between them fails.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# Three things name a release and nothing joined them. v0.124.1 was committed with
# the subject `fix(v0.124.1):` while VERSION still read `0.124.0` and CHANGELOG.md
# had no 0.124.1 heading. pre-push ran six gates and none of them read a version;
# it was found only because the author re-read the commit afterwards.
#
# check-version.sh does not cover this: it compares an INSTALLED consumer's stamp
# against the distribution's VERSION -- a different join, in the other direction,
# silent about the CHANGELOG and about the commit that made the claim.
#
# This fixture builds a THROWAWAY repository rather than asserting against this
# one's history. Asserting against real commits would make the fixture a snapshot
# of whatever the log happens to contain, and it would rot on the next release.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# This validator is DISTRIBUTION tooling, not shipped to consumers -- it governs
# ai-dlc's own release discipline, and a consumer writes no ai-dlc CHANGELOG entry.
# So it lives in scripts/ beside validate-enforcement-map.sh, and unlike the
# core/scripts/ validators it has exactly one home to look in.
VALIDATOR="$ROOT/scripts/validate-release-version.sh"
if [ ! -f "$VALIDATOR" ]; then
  echo "FIXTURE SKIP: validate-release-version.sh not present (consumer install)" >&2
  echo "release-version-triple: PASS (skipped -- distribution-only validator)"
  exit 0
fi
echo "HERMETIC-CONSUMED scripts/validate-release-version.sh"

command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
printf 'HERMETIC-CONSUMED core/fixtures/lib/mutant.sh\n'

# EXPECTED_ASSERTIONS is not bookkeeping. A sibling fixture lost an entire arm
# when a helper call was mis-spaced: `set -u` killed the `$( )` subshell, the `if`
# read that as a false branch, and the arm never ran -- seventeen green lines and a
# PASS. Every assertion below reaches the validator through `$( )`, so the same
# shape is available here. A failed assertion is loud; one that never executed is
# not, and this is what tells them apart.
EXPECTED_ASSERTIONS=32

cd "$WORK" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false

# commit <version> <changelog-version> <subject> -- PREPENDS the heading and keeps
# every one below it. It once rewrote CHANGELOG.md to a single heading, which made
# every commit here REPLACE the previous release's heading in place -- the exact
# shape arm C's removal check now refuses -- so assertions meant for predicates A
# and B would have read red for a range reason.
commit() {
  printf '%s' "$1" > VERSION
  if [ -f CHANGELOG.md ]; then
    { printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$2"
      tail -n +2 CHANGELOG.md; } > CHANGELOG.next
    mv CHANGELOG.next CHANGELOG.md
  else
    printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$2" > CHANGELOG.md
  fi
  git add -A
  git commit -q -m "$3" 2>/dev/null
}

# drive_src <validator-file> <outfile> [args...] -> the validator's own exit status, output in <outfile>.
# SOURCES the file in a subshell and calls the SAME functions its main body calls, in its order,
# minus arm_e and arm_f: those two self-probes each build a scratch repository, the bulk of the
# cost, and no drive through here asks about them. Assertion 1 executes the whole program, so both
# arms are still proved to fire. An `exit` in an
# arm ends this subshell with the arm's status, exactly as it ends the script. A sourced copy that
# defines no arm_ab (an older validator) is refused rather than scored as a pass.
drive_src() {
  local v="$1" out="$2"; shift 2
  (
    # shellcheck disable=SC1090
    . "$v" || exit 97
    command -v arm_ab >/dev/null 2>&1 || exit 98
    # One fx_inproc per entry call (P2's unit for a guarded subject); the literal subject path is passed, since <v>
    # need not end in the subject's root-relative path.
    fx_inproc scripts/validate-release-version.sh; rv_init "$@"
    fx_inproc scripts/validate-release-version.sh; arm_c_range
    fx_inproc scripts/validate-release-version.sh; arm_c
    fx_inproc scripts/validate-release-version.sh; arm_d
    fx_inproc scripts/validate-release-version.sh; arm_ab
    fx_inproc scripts/validate-release-version.sh; rv_report
  ) >"$out" 2>&1
}

run() { # run <rev-or-range-flag> <value>
  drive_src "$VALIDATOR" "$WORK/out.txt" "$1" "$2"
  echo "$?"
}

echo "release-version-triple"

# --- 1. All three agreeing passes ---------------------------------------------
commit 0.1.0 0.1.0 'feat(v0.1.0): the first one'
# The ONE full-program drive of a passing input: the whole validator EXECUTED, so arms E and F run
# their probes and the summary names both as fired. Every other drive goes through drive_src.
bash "$VALIDATOR" --commit HEAD >"$WORK/out.txt" 2>&1; status=$?
if [ "$status" = "0" ] \
   && grep -q 'no committed conflict markers (probe fired both ways)' "$WORK/out.txt" \
   && grep -q 'no misspelled not-discharged citation (probe fired both ways)' "$WORK/out.txt"; then
  ok "subject, VERSION and CHANGELOG all agreeing passes, with arms E and F evaluated end to end"
else
  bad "an agreeing commit failed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 2. THE REAL DEFECT: subject ahead of VERSION ------------------------------
# v0.124.1 exactly: the subject announces a version the tree does not carry.
commit 0.1.0 0.1.0 'fix(v0.1.1): the resident path carried the incident'
status="$(run --commit HEAD)"
if [ "$status" = "1" ] && grep -q 'subject says v0.1.1, VERSION says 0.1.0' "$WORK/out.txt"; then
  ok "a subject naming a version VERSION does not carry fails, and both values are named"
else
  bad "the real defect was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
# The ONE executed run of a FAILING input. Every other failing drive is sourced (drive_src), which
# bypasses the BASH_SOURCE main guard; this one executes the program, so a guard that never calls
# rv_main would exit 0 and print nothing here and this arm would go red.
bash "$VALIDATOR" --commit HEAD >"$WORK/exec-fail.txt" 2>&1; exec_fail_status=$?
if [ "$exec_fail_status" = "1" ] && grep -q 'subject says v0.1.1, VERSION says 0.1.0' "$WORK/exec-fail.txt"; then
  ok "EXECUTED (not sourced) on a failing input the validator exits 1 and names both versions, so the main guard is wired"
else
  bad "the executed validator did not fail assertion 2's input -- exit $exec_fail_status; the BASH_SOURCE main guard may not call rv_main"
  sed 's/^/        /' "$WORK/exec-fail.txt"
fi

# --- 3. VERSION ahead of the CHANGELOG ----------------------------------------
# The other half of the same failure: bumped, announced, changelog never written.
commit 0.2.0 0.1.0 'feat(v0.2.0): bumped without a changelog entry'
status="$(run --commit HEAD)"
if [ "$status" = "1" ] && grep -q "CHANGELOG's top heading says 0.1.0" "$WORK/out.txt"; then
  ok "a VERSION ahead of the CHANGELOG heading fails"
else
  bad "a stale CHANGELOG heading was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 4. A CHANGELOG with no heading at all fails -------------------------------
# Distinct from a stale heading: absence must not read as agreement.
printf '0.3.0' > VERSION
printf '# Changelog\n\nnothing here yet\n' > CHANGELOG.md
git add -A && git commit -q -m 'feat(v0.3.0): no heading'
status="$(run --commit HEAD)"
if [ "$status" = "1" ] && grep -q "no '## \[X.Y.Z\]' heading" "$WORK/out.txt"; then
  ok "a CHANGELOG with no version heading fails rather than passing vacuously"
else
  bad "a missing heading did not fail -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 5. A subject with NO version token is not a failure -----------------------
# Measured on the real repo: 14 of the last 30 bumps predate the convention. A
# check that is wrong about a third of the history it is pointed at gets turned
# off, and takes the working predicates with it. This assertion pins the rejected
# third predicate so it cannot return by accident.
commit 0.4.0 0.4.0 'chore: no version token in this subject'
status="$(run --commit HEAD)"
if [ "$status" = "0" ]; then
  ok "a subject with no version token passes (the rejected predicate stays rejected)"
else
  bad "a tokenless subject failed -- the rejected predicate came back"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 6. MERGES ARE SKIPPED OVER A RANGE ----------------------------------------
# A merge's VERSION differs from its first parent by construction and its subject
# carries no token. Without the skip this fires on every merge to main.
git checkout -q -b side
commit 0.5.0 0.5.0 'feat(v0.5.0): on a branch'
git checkout -q -
git merge -q --no-ff -m 'Merge pull request #1 from side' side
# HEAD~1..HEAD, not HEAD~2: the range still spans the merge AND the side commit it
# brings in, and its base is assertion 5's commit. HEAD~2 is assertion 4's
# headingless commit, so with a cumulative changelog that range adds 0.4.0 and
# 0.5.0 and arm C would fire for a reason this assertion is not about.
status="$(run --range "HEAD~1..HEAD")"
if [ "$status" = "0" ]; then
  ok "a merge commit in the range is skipped, not indicted"
else
  bad "a merge fired -- the check would block every merge to main"; sed 's/^/        /' "$WORK/out.txt"
fi
# And the commit the merge BROUGHT IN is still checked on its own, or the skip is
# a hole rather than a scope.
git checkout -q -b side2
commit 0.6.0 0.5.0 'feat(v0.6.0): bad commit behind a merge'
git checkout -q -
git merge -q --no-ff -m 'Merge pull request #2 from side2' side2
status="$(run --range "HEAD~2..HEAD")"
if [ "$status" = "1" ]; then
  ok "  and a bad commit behind a merge is still caught"
else
  bad "  a bad commit hid behind a merge -- the skip is a hole"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 7a-7d. THE BARE LEADING FORM IS A CLAIM ------------------------------------
# Release subjects in this repo read `0.754.0 — ...`, with no `v`. Under a v-only
# grammar predicate A bound none of them, so it could not fire on a current release.
# Every input above is `feat(vX.Y.Z)`, which is why nothing here noticed.
commit 0.8.0 0.8.0 '0.8.0 — agreeing'
status="$(run --commit HEAD)"
if [ "$status" = "0" ]; then
  ok "a bare leading version agreeing with VERSION passes"
else
  bad "a bare agreeing subject failed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

commit 0.9.0 0.9.0 '0.9.1 — ahead'
status="$(run --commit HEAD)"
if [ "$status" = "1" ] && grep -q 'subject says v0.9.1, VERSION says 0.9.0' "$WORK/out.txt"; then
  ok "a bare leading version ahead of VERSION fails, and both values are named"
else
  bad "a bare leading version ahead of VERSION was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# NEAR-MISS: the same token, mid-subject. A bare version there is a MENTION, not the
# commit's claim about itself, and the fallback is anchored at the start for that reason.
commit 0.9.0 0.9.0 'chore: 0.9.1 mentioned mid-subject'
mid_sha="$(git rev-parse HEAD)"
status="$(run --commit "$mid_sha")"
if [ "$status" = "0" ]; then
  ok "a bare version MID-subject is a mention, not a claim, and passes"
else
  bad "a mid-subject bare version was read as a claim -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- THE RANGE ARMS ------------------------------------------------------------
#
# THE DEFECT THESE EXIST TO CATCH, and it is a different one from assertions 1-7.
# A release branch was cut from a local `main` fourteen commits ahead of
# `origin/main`. The PR took `origin/main` as its merge-base and the squash carried
# three releases under one `feat(v0.217.0):` subject. The triple reported
# `PASS 15 commit(s)` on the branch and `PASS 1 commit(s)` on the squash -- BOTH
# PASS, because the commits that could have disagreed are precisely the ones the
# squash removed. So these assertions must show a red that the triple cannot
# produce, on an input the triple calls green.
#
# A SECOND SANDBOX, deliberately. The repository above is shaped for the triple --
# a headingless commit, merges, repeated headings -- and its history is not a
# release sequence. A clean cumulative changelog is what the arm is pointed at.
W2="$WORK/cumulative"
mkdir -p "$W2" && cd "$W2" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed in W2" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false

# release <version> <subject> -- PREPENDS a heading, the way a real CHANGELOG grows.
# VERSION always matches the newest heading, so the triple stays green throughout
# and every red below is attributable to a range arm.
release() {
  printf '%s' "$1" > VERSION
  if [ -f CHANGELOG.md ]; then
    { printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$1"
      tail -n +2 CHANGELOG.md; } > CHANGELOG.next
    mv CHANGELOG.next CHANGELOG.md
  else
    printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$1" > CHANGELOG.md
  fi
  git add -A
  git commit -q -m "$2" 2>/dev/null
}

release 0.1.0 'feat(v0.1.0): the first one'
base_sha="$(git rev-parse HEAD)"
release 0.2.0 'feat(v0.2.0): one release, on its own branch'
one_sha="$(git rev-parse HEAD)"

# --- 8. One release in a range is silent ---------------------------------------
status="$(run --range "$base_sha..$one_sha")"
if [ "$status" = "0" ]; then
  ok "a range adding ONE release heading passes -- the arm can be quiet"
else
  bad "a single-release range failed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 9. Two releases in a range fail, and both are named -----------------------
release 0.3.0 'feat(v0.3.0): a second release on the same branch'
two_sha="$(git rev-parse HEAD)"
status="$(run --range "$base_sha..$two_sha")"
if [ "$status" = "1" ] \
   && grep -q 'adds 2 release headings' "$WORK/out.txt" \
   && grep -qF '0.2.0' "$WORK/out.txt" && grep -qF '0.3.0' "$WORK/out.txt"; then
  ok "a range adding TWO release headings fails, and names both versions"
else
  bad "a two-release range was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 10. THE SQUASH ITSELF: one commit, two releases, triple in full agreement --
# This is the load-bearing assertion. The commit's subject, VERSION and top
# CHANGELOG heading all name 0.5.0, so predicates A and B are satisfied; only the
# range arm can produce a red here.
git checkout -q -b squashed "$two_sha"
printf '0.5.0' > VERSION
{ printf '# Changelog\n\n## [0.5.0] — 2026-01-01\n\n- entry\n\n## [0.4.0] — 2026-01-01\n\n- entry\n'
  tail -n +2 CHANGELOG.md; } > CHANGELOG.next
mv CHANGELOG.next CHANGELOG.md
git add -A
git commit -q -m 'feat(v0.5.0): two releases squashed into one commit (#1)'
squash_sha="$(git rev-parse HEAD)"
status="$(run --commit "$squash_sha")"
if [ "$status" = "1" ] && grep -q 'adds 2 release headings' "$WORK/out.txt"; then
  ok "a SQUASH carrying two releases fails, though its subject, VERSION and top heading all agree"
else
  bad "the squash shape was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi


# --- THE BRANCH-BASE ARM -------------------------------------------------------
# The PRECONDITION of the squash above: commits sitting on local main and not on
# origin/main are behind the PR's merge-base, so they ride into it unremarked.
W3="$WORK/branchbase"
mkdir -p "$W3" && cd "$W3" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed in W3" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false
release 0.1.0 'feat(v0.1.0): the first one'
git branch -M main
# origin/main is a real ref, not a real remote -- the arm reads refs, not network.
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
git commit -q --allow-empty -m 'chore: a tick committed to main and never pushed'
ahead_main="$(git rev-parse HEAD)"
git checkout -q -b release/0.2.0
release 0.2.0 'feat(v0.2.0): cut from a main that was ahead'

run0() { drive_src "$VALIDATOR" "$WORK/out.txt"; echo "$?"; }

# --- 13. A branch cut from an ahead main fails ---------------------------------
# Note the range arm stays quiet here: only 0.2.0 is added past origin/main. The
# red is the branch-base arm's alone.
status="$(run0)"
if [ "$status" = "1" ] && grep -q 'carries 1 commit(s) that are on local main and not on origin/main' "$WORK/out.txt"; then
  ok "a branch carrying an unpushed main commit fails, and the count is named"
else
  bad "the ahead-main precondition was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 15. CONTROL: caught-up origin/main goes silent ----------------------------
# Keyed on the INHERITANCE, not on merely standing on a branch. Same branch, same
# commits, one ref moved.
git update-ref refs/remotes/origin/main "$ahead_main"
status="$(run0)"
if [ "$status" = "0" ]; then
  ok "CONTROL: the same branch passes once origin/main carries those commits"
else
  bad "a clean branch failed -- the arm fires on being on a branch at all"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 16. The remedy is not indicted --------------------------------------------
# Pushing main is HOW unpushed main commits reach origin. An arm that fires on the
# remedy is an arm that gets turned off, so it must be n/a there -- and must SAY
# it is n/a rather than reporting the same green as an evaluated run.
git update-ref refs/remotes/origin/main "$(git rev-parse main~1)"
git checkout -q main
status="$(run0)"
if [ "$status" = "0" ] && grep -q 'branch-base arm n/a on main' "$WORK/out.txt"; then
  ok "on main the branch-base arm is n/a, and the summary says so rather than claiming a green arm"
else
  bad "the arm fired on main, or reported an unevaluated arm as green -- exit $status"
  sed 's/^/        /' "$WORK/out.txt"
fi

# --- 17. An arm that CANNOT be evaluated announces itself ----------------------
# A quiet skip reads exactly like a pass. With no origin/main there is nothing to
# compare against, and that has to be visible in the output.
git checkout -q release/0.2.0
git update-ref -d refs/remotes/origin/main
status="$(run0)"
if [ "$status" = "0" ] \
   && grep -q 'branch-base arm not evaluated' "$WORK/out.txt" \
   && grep -q 'BRANCH-BASE ARM NOT EVALUATED' "$WORK/out.txt"; then
  ok "with no origin/main the arm announces it did not run, in the NOTE and in the summary"
else
  bad "an unevaluated arm passed silently -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 18. An EMPTY range falls back to HEAD, and the verdict names the substitution
# With no commits of its own, a branch's HEAD is origin/main's tip -- somebody else's
# already-merged release, whose triple agrees by construction. A bare `PASS 1 commit(s)`
# there is a check that cannot fire reading exactly like one that passed, and it reads
# that way at the moment a rehearsal is most likely: before the release commit exists.
git checkout -q release/0.2.0
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
status="$(run0)"
if [ "$status" = "0" ] && grep -q 'range origin/main..HEAD was EMPTY' "$WORK/out.txt"; then
  ok "an empty range names the commit it fell back to instead of reporting a bare pass"
else
  bad "an empty range reported a pass without naming its substituted subject -- exit $status"
  sed 's/^/        /' "$WORK/out.txt"
fi

# --- 19. CONTROL: the note is not unconditional --------------------------------
# On main the fallback IS the intended subject, and `branch-base arm n/a on main`
# already says where the run is. A note that printed everywhere would be noise, and
# noise is how a real signal stops being read.
git checkout -q main
status="$(run0)"
if [ "$status" = "0" ] && ! grep -q 'was EMPTY' "$WORK/out.txt"; then
  ok "CONTROL: on main the same empty range prints no note (so assertion 18 is not unconditional)"
else
  bad "the empty-range note fired on main, where the fallback is the intended subject -- exit $status"
  sed 's/^/        /' "$WORK/out.txt"
fi

# --- 20/21. ARM F'S CANONICAL GRAMMAR IS THE ENGINE'S, BYTE FOR BYTE ------------
# The consumer engine's `named_cited_filter` strips a citation line only in its exact
# form; arm F refuses every other spelling. Two copies of one regex in two trees (the
# engine ships, this validator does not), so they are bound here: each file must carry
# EXACTLY ONE `/^Not-discharged: ...$/` literal, and the two must be byte-identical.
# A copy that drifts narrower or wider lets arm F acquit a line the engine reads as an
# ordinary mention -- the false absorption the form exists to prevent.
ENGINE="$ROOT/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
canon_of() { grep -o '/\^Not-discharged: [^/]*\$/' "$1" 2>/dev/null; }
pair_ok() { # <engine> <validator> -> 0 when each has exactly one literal and they agree
  local a b
  a="$(canon_of "$1")"; b="$(canon_of "$2")"
  [ "$(printf '%s\n' "$a" | grep -c .)" = 1 ] && [ "$(printf '%s\n' "$b" | grep -c .)" = 1 ] && [ "$a" = "$b" ]
}
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
if [ ! -f "$ENGINE" ]; then
  bad "the engine is absent at $ENGINE, so the grammar pair cannot be compared"
elif pair_ok "$ENGINE" "$VALIDATOR"; then
  ok "arm F's canonical citation regex is byte-identical to the engine's: $(canon_of "$VALIDATOR")"
else
  bad "the citation grammar has forked: engine {$(canon_of "$ENGINE" | tr '\n' ' ')} validator {$(canon_of "$VALIDATOR" | tr '\n' ' ')}"
fi

# --- R1-R5. ARM C IN BOTH DIRECTIONS: REMOVED HEADINGS, RESTORED HEADINGS --------
#
# TWO DEFECTS A COUNT OF ADDED HEADINGS COULD NOT SEE. 0.806.0 (581ca289) turned
# the previous release's `## [0.805.0]` into `## [0.806.0]` in place: the set
# difference netted to one added heading and the release PASSED, with 0.805.0's
# body left filed under 0.806.0. And the repair of that shape (ed0fa33d restored
# `[0.805.0]`) plus the next release counted two and FAILED. So arm C now refuses
# a removed heading, and sets aside a below-the-base-top heading the base's own
# history already carried.
#
# A FOURTH SANDBOX, each world written out in full by `snap`, so every heading set
# is stated rather than inferred from a prepend history. Every world keeps VERSION
# equal to its top heading and every subject agreeing, so every red is arm C's.
W4="$WORK/headings"
mkdir -p "$W4" && cd "$W4" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed in W4" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false

# snap <version> <subject> <heading versions, top first...>
snap() {
  local v="$1" s="$2" h
  shift 2
  printf '%s' "$v" > VERSION
  { printf '# Changelog\n'
    for h in "$@"; do printf '\n## [%s] — 2026-01-01\n\n- entry\n' "$h"; done; } > CHANGELOG.md
  git add -A
  git commit -q -m "$s" 2>/dev/null
}

snap 0.1.0 '0.1.0 — first' 0.1.0
snap 0.2.0 '0.2.0 — second' 0.2.0 0.1.0
c2_sha="$(git rev-parse HEAD)"
# THE 0.806.0 SHAPE: 0.2.0's heading line becomes 0.3.0's, its body stays.
snap 0.3.0 '0.3.0 — replaces the previous heading in place' 0.3.0 0.1.0
r1_sha="$(git rev-parse HEAD)"
git checkout -q -b r2 "$c2_sha"
snap 0.3.0 '0.3.0 — inserted above, as a release should be' 0.3.0 0.2.0 0.1.0
r2_sha="$(git rev-parse HEAD)"
# THE ed0fa33d SHAPE: 0.2.0 is restored below the base's top, plus one new release.
git checkout -q -b r3 "$r1_sha"
snap 0.4.0 '0.4.0 — restores 0.2.0 and releases' 0.4.0 0.3.0 0.2.0 0.1.0
r3_sha="$(git rev-parse HEAD)"
git checkout -q -b r4 "$r1_sha"
snap 0.5.0 '0.5.0 — two genuinely new releases' 0.5.0 0.4.0 0.3.0 0.1.0
r4_sha="$(git rev-parse HEAD)"
# BELOW THE BASE TOP, NEVER IN HISTORY. Only the base's history decides it; a
# search from the TIP finds this very commit and would exempt it.
git checkout -q -b r5 "$r1_sha"
snap 0.4.0 '0.4.0 — invents a below-top heading' 0.4.0 0.3.0 0.2.5 0.1.0
r5_sha="$(git rev-parse HEAD)"

drive() { # drive <validator> <sha> <outfile> -> exit status
  drive_src "$1" "$3" --commit "$2"
  echo "$?"
}

status="$(drive "$VALIDATOR" "$r1_sha" "$WORK/out.txt")"
if [ "$status" = "1" ] && grep -q 'removes release heading(s) present at its base: 0.2.0' "$WORK/out.txt" \
   && ! grep -q 'adds 2 release headings' "$WORK/out.txt"; then
  ok "R1: a release that replaces the previous heading in place fails, naming the removed heading"
else
  bad "R1: an in-place heading replacement was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

status="$(drive "$VALIDATOR" "$r2_sha" "$WORK/out.txt")"
if [ "$status" = "0" ] && grep -q 'no heading removed' "$WORK/out.txt"; then
  ok "R2: a normal insertion above the previous heading passes"
else
  bad "R2: a normal release failed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

status="$(drive "$VALIDATOR" "$r3_sha" "$WORK/out.txt")"
if [ "$status" = "0" ] && grep -q 'NOTE  restored historical heading(s), not counted: 0.2.0' "$WORK/out.txt"; then
  ok "R3: restoring a historical heading plus one new release passes, and the restore is NOTEd"
else
  bad "R3: a restored heading was counted as a release -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

status="$(drive "$VALIDATOR" "$r4_sha" "$WORK/out.txt")"
if [ "$status" = "1" ] && grep -q 'adds 2 release headings' "$WORK/out.txt"; then
  ok "R4: two genuinely new headings above the base top still fail"
else
  bad "R4: two new releases passed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

status="$(drive "$VALIDATOR" "$r5_sha" "$WORK/out.txt")"
if [ "$status" = "1" ] && grep -q 'adds 2 release headings' "$WORK/out.txt" && grep -qF '0.2.5' "$WORK/out.txt"; then
  ok "R5: a below-top heading the base's history never carried counts as new"
else
  bad "R5: an invented below-top heading was exempted -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi


# --- S1-S5. A RELEASE STACKED ON A PUSHED, UNLANDED RELEASE (BL-1047) -----------
# The default range once ran from origin/main only, so a release stacked on another release that
# was pushed for its own gate and had not landed read as a two-release branch and failed its push.
# The base is now the nearest pushed release ancestor, searched only when the caller passes the
# push's remote and ref lines, and never one the push itself names (the validator's USAGE block).
# EVERY PUSH CELL IS A REAL `git push` to a scratch bare origin, whose pre-push hook captures "$1"
# and its stdin -- the lines git hands .githooks/pre-push -- into .git/ and refuses, so nothing
# lands and the cell is judged at hook time. The validator then gets them exactly as step 1c of
# that hook passes them: --push-remote "$1" --push-refs "<stdin>". S1 the stack passes and names
# its base; S2 the stack over a NEVER-pushed release fails; S3 two releases above the pushed base
# fail; S4 ONE branch collecting two releases across two pushes fails, though its first push left
# origin/<branch> containing the lower one; S5 the stack with NO push refs fails closed. The
# capture hook is /bin/sh, so the push starts no counted bash. A FIFTH SANDBOX.
W5="$WORK/stacked"
mkdir -p "$W5" "$WORK/capture-hooks" && cd "$W5" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed in W5" >&2; exit 2; }
git init -q --bare "$WORK/stacked-origin.git" 2>/dev/null || { echo "FIXTURE ERROR: git init --bare failed" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false
git remote add origin "$WORK/stacked-origin.git"
# git exports no GIT_DIR to a pre-push hook and runs it at the work tree's top, so .git/ is relative.
printf '%s\n' '#!/bin/sh' 'printf %s "$1" > .git/ai-dlc-push-remote' 'cat > .git/ai-dlc-push-lines' 'exit 1' \
  > "$WORK/capture-hooks/pre-push"
chmod +x "$WORK/capture-hooks/pre-push"
real_push() { git -c core.hooksPath=/dev/null push -q origin "HEAD:refs/heads/$1" >/dev/null 2>&1 || { echo "FIXTURE ERROR: setup push of $1 failed" >&2; exit 2; }; }
# capture <branch> -- a refused push of HEAD to <branch>, leaving the hook's two inputs in .git/.
capture() {
  rm -f .git/ai-dlc-push-remote .git/ai-dlc-push-lines
  git -c core.hooksPath="$WORK/capture-hooks" push -q origin "HEAD:refs/heads/$1" >/dev/null 2>&1
  [ -s .git/ai-dlc-push-lines ] && grep -q " refs/heads/$1 " .git/ai-dlc-push-lines \
    || { echo "FIXTURE ERROR: the capture hook recorded no ref line for $1" >&2; exit 2; }
}
# drive_push <validator> <outfile> -- the sourced drive, given the captured push as the hook gives it.
drive_push() { drive_src "$1" "$2" --push-remote "$(cat .git/ai-dlc-push-remote)" --push-refs "$(cat .git/ai-dlc-push-lines)"; }
release 0.1.0 '0.1.0 — landed'
git branch -M main
real_push main
git checkout -q -b lower main
release 0.2.0 '0.2.0 — pushed for its own gate, not landed'
git commit -q --allow-empty -m 'a fix above the lower release commit'
real_push lower
git checkout -q -b local-lower main
release 0.2.0 '0.2.0 — committed and never pushed'
git checkout -q -b squash3 lower
printf '0.4.0' > VERSION
{ printf '# Changelog\n\n## [0.4.0] — 2026-01-01\n\n- entry\n\n## [0.3.0] — 2026-01-01\n\n- entry\n'
  tail -n +2 CHANGELOG.md; } > CHANGELOG.next
mv CHANGELOG.next CHANGELOG.md
git add -A
git commit -q -m '0.4.0 — squashes 0.3.0 in above the pushed release'
git checkout -q -b stacked-local local-lower
release 0.3.0 '0.3.0 — stacked on an unpushed release'
git checkout -q -b samebr main
release 0.2.0 '0.2.0 — first release on the collecting branch'
real_push samebr
release 0.3.0 '0.3.0 — second release on the collecting branch'
git checkout -q -b stacked lower
release 0.3.0 '0.3.0 — stacked on the pushed release'
git fetch -q origin 2>/dev/null
stack_lower="$(git rev-parse lower~1)"

capture stacked
drive_push "$VALIDATOR" "$WORK/out.txt"; status=$?
if [ "$status" = "0" ] && grep -q "range base is the pushed release $stack_lower on origin/lower" "$WORK/out.txt" \
   && ! grep -q 'adds 2 release headings' "$WORK/out.txt"; then
  ok "S1: a release stacked on a pushed, unlanded release passes its push, and names that release as its range base"
else
  bad "S1: a stacked release failed its push or did not name its pushed base -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

# S5 reads the same commits with no push refs: a hand run, the old hook. It must range from origin/main.
drive_src "$VALIDATOR" "$WORK/out.txt"; status=$?
if [ "$status" = "1" ] && grep -q 'adds 2 release headings to CHANGELOG.md: 0.2.0 0.3.0' "$WORK/out.txt" \
   && ! grep -q 'range base is the pushed release' "$WORK/out.txt"; then
  ok "S5: the same stack with no push refs fails closed, as two releases from origin/main"
else
  bad "S5: a run given no push refs took a stacked base -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

git checkout -q stacked-local
capture stacked-local
drive_push "$VALIDATOR" "$WORK/out.txt"; status=$?
if [ "$status" = "1" ] && grep -q 'adds 2 release headings to CHANGELOG.md: 0.2.0 0.3.0' "$WORK/out.txt" \
   && ! grep -q 'range base is the pushed release' "$WORK/out.txt"; then
  ok "S2: the same stack over a release that was never pushed still fails its push as two releases"
else
  bad "S2: an unpushed lower release served as a range base -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

git checkout -q squash3
capture squash3
drive_push "$VALIDATOR" "$WORK/out.txt"; status=$?
if [ "$status" = "1" ] && grep -q "range base is the pushed release $stack_lower" "$WORK/out.txt" \
   && grep -q 'adds 2 release headings to CHANGELOG.md: 0.3.0 0.4.0' "$WORK/out.txt"; then
  ok "S3: a commit squashing two releases above the pushed base fails its push from that base"
else
  bad "S3: two releases above a pushed base passed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

git checkout -q samebr
capture samebr
drive_push "$VALIDATOR" "$WORK/out.txt"; status=$?
if [ "$status" = "1" ] && grep -q 'adds 2 release headings to CHANGELOG.md: 0.2.0 0.3.0' "$WORK/out.txt" \
   && ! grep -q 'range base is the pushed release' "$WORK/out.txt" \
   && grep -q ' refs/heads/samebr [0-9a-f]*[1-9a-f][0-9a-f]*$' .git/ai-dlc-push-lines; then
  ok "S4: one branch collecting a second release after its first push fails, though origin/samebr holds the first"
else
  bad "S4: the branch's own earlier push served as its range base -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi

cd "$WORK" || exit 2
# --- 24. EVERY NEAR-MISS REACHES ARM E'S PROBE TREE -----------------------------
# m-e-nospace proves one near-miss arrived. setext.md and openonly.md are written the same way,
# and a near-miss that never reached the tree is quiet exactly as a correctly-acquitted one is.
# rv_probe_e_tree is the function arm E calls, sourced and run here on a fresh directory, and its
# HEAD tree must list exactly the offender and the three near-misses.
E_TREE="$WORK/e-tree"
mkdir -p "$E_TREE" || exit 2
( . "$VALIDATOR" || exit 97; fx_inproc scripts/validate-release-version.sh; rv_probe_e_tree "$E_TREE" ) >/dev/null 2>&1
e_names="$(git -C "$E_TREE" ls-tree -r --name-only HEAD 2>/dev/null | tr '\n' ' ')"
if [ "$e_names" = "nospace.md offender.md openonly.md setext.md " ]; then
  ok "arm E's probe tree, built by the function arm E calls, holds the offender and all three near-misses: $e_names"
else
  bad "arm E's probe tree lists [$e_names], want the offender and the three near-misses"
fi

echo ""
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "release-version-triple: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. An arm did not execute at all, which is not the same as an arm that passed. Find the one that vanished before reading anything above as green."
  exit 1
fi
if [ "$fails" -eq 0 ]; then
  echo "release-version-triple: PASS ($made assertions)"
  exit 0
fi
echo "release-version-triple: FAIL ($fails of $made assertion(s))"
exit 1
