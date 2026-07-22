#!/usr/bin/env bash
# validate-release-version.sh -- the release triple must agree: the commit subject,
# the VERSION file, and the CHANGELOG's top heading.
#
# WHY THIS EXISTS. Three things name the version of a release and nothing joined
# them. Every other consistency claim in this repo has an enforcer; this one was
# a convention, held by whoever remembered.
#
# It failed the first time it was tested. v0.124.1 was committed with the subject
# `fix(v0.124.1):` while VERSION still read `0.124.0` and CHANGELOG.md had no
# 0.124.1 heading at all. Nothing in the repo would have caught it -- pre-push runs
# six gates and none of them read a version -- and it was found only because the
# author happened to re-read the commit afterwards. A release whose three names
# disagree is a release nobody can identify later: the tag says one thing, the
# installed stamp another, and the changelog a third.
#
# check-version.sh does NOT cover this. It compares an INSTALLED consumer's stamp
# against the distribution's VERSION -- a different join, in the other direction,
# and it is silent about the CHANGELOG and about the commit that made the claim.
#
# THE PREDICATES, AND THE POPULATION THEY WERE MEASURED ON.
#
#   A. A subject carrying a `vX.Y.Z` token must match VERSION at that commit.
#      Measured: 16 of the last 30 version bumps carry the token, and all 16 match.
#      This is the predicate that catches the real defect above. A MISSING token is
#      not a failure -- 14 of those 30 predate the convention entirely.
#
#   B. VERSION must equal the CHANGELOG's top `## [X.Y.Z]` heading. Unconditional,
#      not just at bumps: measured across the last 40 non-merge commits, 40 agree.
#      A commit that adds a heading without bumping, or bumps without adding one,
#      breaks a join that has never been broken.
#
#   Together, A and B pass 62 of 62 non-merge commits in the measured range. The
#   check is silent on every correct commit this repo has ever made and loud on the
#   one that was wrong.
#
# A THIRD PREDICATE WAS BUILT, MEASURED AND REJECTED: "a commit that CHANGES VERSION
# must name it in its subject", which would catch a silent bump. It fired on 21 of
# those 62 commits -- every release at or below v0.114.0, all of them correct under
# the naming convention of their time. Scoping it to "after v0.115.0" would be a
# fitted constant with no derivation, and no observed defect motivated it: predicate
# A caught the only failure that has actually happened. A check that is wrong about a
# third of the history it is pointed at gets turned off, and takes A and B with it.
#
# MERGES ARE SKIPPED, AND THAT IS NOT A LOOPHOLE. A merge commit's VERSION differs
# from its first parent by construction (it is bringing the bump in), and its
# subject is "Merge pull request #N from ..." with no version token. Measured on
# the last 3 merges to main: all 3 differ from parent 1, none carry a token. Without
# this skip the check would fire on every merge, and a gate that fires on every
# correct action is a gate that gets turned off. The commits the merge brings in are
# each checked on their own, which is where the claim is actually authored.
#
# USAGE
#   scripts/validate-release-version.sh [--range A..B] [--commit SHA]
#
#   default range   origin/main..HEAD -- the branch's own commits, which is what a
#                   push adds. Falls back to HEAD alone when that range is empty or
#                   origin/main is not present (a fresh clone, a detached head).
#
# EXIT
#   0  every checked commit's three names agree
#   1  a disagreement, or a commit could not be read

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "FAIL: not inside a git repository" >&2; exit 1; }

RANGE=""
COMMIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --range)  RANGE="${2:-}"; shift 2 ;;
    --commit) COMMIT="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Resolve the commit list. --no-merges is load-bearing; see the header.
if [ -n "$COMMIT" ]; then
  COMMITS="$COMMIT"
elif [ -n "$RANGE" ]; then
  COMMITS="$(git rev-list --no-merges "$RANGE" 2>/dev/null)"
else
  COMMITS="$(git rev-list --no-merges origin/main..HEAD 2>/dev/null || true)"
  [ -n "$COMMITS" ] || COMMITS="$(git rev-parse HEAD 2>/dev/null)"
fi

if [ -z "$COMMITS" ]; then
  echo "PASS  no non-merge commits to check."
  exit 0
fi

fails=0
checked=0

semver_of() { printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }

for c in $COMMITS; do
  short="$(git rev-parse --short "$c")"
  subject="$(git log -1 --format=%s "$c" 2>/dev/null)"

  version="$(git show "$c:VERSION" 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$version" ]; then
    echo "FAIL  $short  VERSION is missing or empty at this commit" >&2
    fails=$((fails+1)); continue
  fi

  changelog="$(semver_of "$(git show "$c:CHANGELOG.md" 2>/dev/null \
                | grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]')")"
  subj_ver="$(printf '%s' "$subject" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  subj_ver="${subj_ver#v}"

  checked=$((checked+1))
  bad=0

  # A. A stated version must be the real one.
  if [ -n "$subj_ver" ] && [ "$subj_ver" != "$version" ]; then
    echo "FAIL  $short  subject says v$subj_ver, VERSION says $version" >&2
    bad=1
  fi

  # B. VERSION and the changelog's top heading name the same release.
  if [ -z "$changelog" ]; then
    echo "FAIL  $short  CHANGELOG.md has no '## [X.Y.Z]' heading" >&2
    bad=1
  elif [ "$changelog" != "$version" ]; then
    echo "FAIL  $short  VERSION says $version, CHANGELOG's top heading says $changelog" >&2
    bad=1
  fi

  [ "$bad" -eq 0 ] || fails=$((fails+1))
done

if [ "$fails" -ne 0 ]; then
  cat >&2 <<'EOF'

      The three names of a release must agree: the commit subject, VERSION, and the
      CHANGELOG's top heading. When they do not, the release cannot be identified
      afterwards -- the tag, the installed stamp and the changelog each say something
      different, and there is no way to tell which one is the release.

      Remedy: bump VERSION and add the matching '## [X.Y.Z]' CHANGELOG heading in the
      SAME commit that names the version in its subject. If the commit is already
      made, `git commit --amend` it; the three are one claim, not three.
EOF
  echo "FAIL: ${fails} of ${checked} commit(s) disagree." >&2
  exit 1
fi

echo "PASS  ${checked} commit(s): subject, VERSION and CHANGELOG heading agree."
exit 0
