#!/usr/bin/env bash
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

command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

cd "$WORK" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false

# commit <version> <changelog-version> <subject>
commit() {
  printf '%s' "$1" > VERSION
  printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$2" > CHANGELOG.md
  git add -A
  git commit -q -m "$3" 2>/dev/null
}

run() { # run <rev-or-range-flag> <value>
  bash "$VALIDATOR" "$1" "$2" >"$WORK/out.txt" 2>&1
  echo "$?"
}

echo "release-version-triple"

# --- 1. All three agreeing passes ---------------------------------------------
commit 0.1.0 0.1.0 'feat(v0.1.0): the first one'
status="$(run --commit HEAD)"
if [ "$status" = "0" ]; then
  ok "subject, VERSION and CHANGELOG all agreeing passes"
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
status="$(run --range "HEAD~2..HEAD")"
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

# --- 7. THE MUTATION TEST — prove assertion 2's red is predicate A's -----------
# Neuter the subject comparison on a COPY and demand assertion 2's input go green.
MUTANT="$WORK/mutant.sh"
sed 's/\[ "\$subj_ver" != "\$version" \]/false/' "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- predicate A was rewritten" >&2
  echo "  update the sed pattern in assertion 7 to match the real comparison" >&2
  exit 2
fi
commit 0.7.0 0.7.0 'fix(v0.7.1): subject ahead again'
bash "$MUTANT" --commit HEAD >"$WORK/mut.txt" 2>&1
mutant_status=$?
if [ "$mutant_status" = "0" ]; then
  ok "MUTATION: disabling the subject comparison makes assertion 2's input go green"
else
  bad "MUTATION: assertion 2's input still fails (exit $mutant_status) without predicate A"
  sed 's/^/        /' "$WORK/mut.txt"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "release-version-triple: PASS"
  exit 0
fi
echo "release-version-triple: FAIL ($fails assertion(s))"
exit 1
